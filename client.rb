require 'socket'
require 'digest'
require 'ipaddress'

# Read config file method
def read_config(config_param)
  File.foreach("client.config") do |line|
    if line.split(':')[0] == config_param
      return line.split(': ')[1].chomp
    end
  end
end

# Connect to torrent server
sock = TCPSocket.open(read_config('serverip'), read_config('serverport'))

def updatetracker(file_name, start_bytes, end_bytes, ipaddress, port)
  puts "in update"
  sock = TCPSocket.open(read_config('serverip'), read_config('serverport'))
  sock.puts "<updatetracker #{file_name} #{start_bytes} #{end_bytes} #{ipaddress} #{port}>"
  msg = sock.gets.chomp
  puts msg
  if msg == "<updatetracker #{file_name} succ>" 
    puts "  #{file_name}.track updated"
  elsif msg == "<updatetracker #{file_name} ferr>"
    puts "  No tracker for #{file_name}"
  else
    puts "  updatetracker failed for #{file_name}"
  end
end

def run_get(tracker)
  # Get information about peers
  sock = TCPSocket.open(read_config('serverip'), read_config('serverport'))
  sock.puts "<GET #{tracker}>"
  puts "sent request"
  input = ''
  filename = ''
  filesize = 0
  md5 = ''
  ip = ''
  port = ''
  time = ''
  sbyte = ''
  ebyte = ''
  seederarray = Array.new
  index = 0
  until input.split()[2] == 'END' or input == '<GET INVALID>' do
    
    input = sock.gets
    if input.split(':')[0] == '<Filename'
      filename = input.split(': ')[1]
    elsif input.split(':')[0] == 'Filesize'
      filesize = input.split(': ')[1].to_i
    elsif input.split(':')[0] == 'MD5'
      md5 = input.split(': ')[1]
    elsif IPAddress.valid?(input.split(':')[0]) or input.split(':')[0] == 'localhost'
      ip = input.split(':')[0]
      port = input.split(':')[1]
      sbyte = input.split(':')[2]
      ebyte = input.split(':')[3]
      time = input.split(':')[4].chomp
      time[-1] = ''
      seederarray[index] = "#{time} #{ip} #{port} #{sbyte} #{ebyte}"
      index += 1
    end
  end
  
  if input.split()[3] == "#{md5.chomp}>"
    # Contact peer for file
    seederchunks = Array.new
    seedertimes = Array.new
    puts "seederarray: #{seederarray}"
    seederarray.each do |q|
	    seedertimes.push(q.split()[0].to_i)
    end
    seedertimes.sort
    
    #seederheap = Maxheap.new(seederarray[].split()[0])->new_heap
    chunksize = read_config('chunksize').to_i
    count=0
    until seederchunks.length == (filesize.to_f / chunksize.to_f).ceil do
      seederarray.each do |n|
        if n.split()[0].to_i == seedertimes[-1]
			    seederchunks[count] = n.split()[1,2]
			    seedertimes.push(seedertimes.pop)
			    count+=1
	    	end
	    end
    end
    
    # Create thread to download from each seeder
    seederarray.each do |s|
      Thread.new {
      puts "thread created"
        ip = s.split()[1]
        port = s.split()[2]            
        iter = 0
        puts "num chunks: #{seederchunks.length}"
        until iter > seederchunks.length do
			
          if seederchunks[iter].join(" ") == "#{ip} #{port}" #AND Dir["./Files/#{filename}.part#{iter}"].size == 0
            data = ''
            puts "inside if"
            
            
            begin
              inc_sock = TCPSocket.open(ip, port)
              inc_sock.puts "#{filename.chomp} #{chunksize * iter} #{chunksize}"
              puts "Requesting bytes #{chunksize * iter} up to #{chunksize * iter + chunksize} of #{filename.chomp} from #{ip}:#{port}"
              data = inc_sock.read
            rescue
              ip = seederchunks[iter + 1].split()[0]
              port = seederchunks[iter + 1].split()[1]
              inc_sock = TCPSocket.open(ip, port)
              inc_sock.puts "#{filename.chomp} #{chunksize * iter} #{chunksize}"
              puts "Requesting bytes #{chunksize * iter} up to #{chunksize * iter + chunksize} of #{filename.chomp} from #{ip}:#{port}"
              data = inc_sock.read
            end
            if data.size > chunksize
              data = data[0, chunksize]
            end
            file = File.open("./Files/#{filename.chomp}.part#{iter}", 'wb')
            file.print data
            puts "wrote data to file"
            file.close
            inc_sock.close
            puts "socket closed"
            updatetracker(filename.chomp, 0, (chunksize * iter + chunksize < filesize ? chunksize * iter + chunksize : filesize), ip, port)
            puts "we update tracker"
          end
          iter += 1
        end
        s = "finished"
      }
    end
    
    # Loop until all parts are had
   complete = false
    until complete do
      complete = true
      seederarray.each do |s|
        if s != "finished"
          complete = false
        end
      sleep 1
      end
      puts complete
    end
    
    puts "Constructing File: #{filename.chomp}"
    fcount= 0
    until fcount > seederchunks.size do
      File.open("./Files/#{filename.chomp}", 'a') { |f| f.print File.binread("./Files/#{filename.chomp}.part#{fcount}") }
      File.delete("./Files/#{filename.chomp}.part#{fcount}")
      fcount += 1
    end

    updatetracker filename, 0, File.size("./Files/#{filename}"), read_config('ip'), read_config('port')
    puts "update after file constructed"
  else 
    puts '  GET failed for #{command.split()[1]}'
  end
end

# First time launch file creation
if !Dir.exist? 'Files' 
  Dir.mkdir 'Files'
end

# Check for config file
if !File.exist? 'client.config'
  config = File.new "client.config", 'w'
  config.puts "ip: localhost"
  config.puts "port: 8687"
  config.puts "serverip: localhost"
  config.puts "serverport: 8686"
  config.puts "chunksize: 1024"
  config.puts "updatetime: 900"
  config.close
end

# Check for incomplete downloads
#parts = Dir['./Files/*.part*']
#if parts.size > 0
#  run_get "#{parts}.track"
#end


# Create thread to manage file requests from other peers
server = TCPServer.open(read_config('port'))
Thread.new {
	
  loop {
    begin
      Thread.start(server.accept) do |client|
        message = client.gets
        message = message.split()
        puts "message received #{message}"
        
        if !File.exist? "./Files/#{message[0]}"
	      message[0] = "#{message[0].part}#{(message[1].to_f/message[2].to_f).ceil}"
        end
        
        if message[2].to_i > 1024
	          contents = "<GET invalid>"
	        elsif (message[1].to_i + message[2].to_i) > File.size("./Files/#{message[0]}")
	          contents = File.read("./Files/#{message[0]}", File.size("./Files/#{message[0]}") - message[1].to_i, message[1].to_i)
	        else
	          contents = File.read("./Files/#{message[0]}", message[2].to_i, message[1].to_i)
	      end
	      client.puts contents
        client.close
      end
    rescue 
    end
  }
}

ARGV.clear

loop do
  print "ptpterminal: "
  command = gets.chomp
  
  case command.split()[0]
  
  when 'SEED'
    # SEED filepath desc yourip yourport
    input = command.split
    size = File.size("./Files/#{input[1]}")
    md5 = Digest::MD5.file("./Files/#{input[1]}").hexdigest
    sock.puts "<createtracker #{input[1]} #{size} #{input[2]} #{md5} #{read_config('ip')} #{read_config('port')}>"
    msg = sock.gets.chomp
    if msg == "<createtracker succ>" 
      puts "  #{input[1]}.track created"
    elsif msg == "<createtracker ferr>"
      puts "  Duplicate tracker for #{input[1]}"
    else
      puts "  createtracker failed for #{input[1]}"
    end
      
  when 'LIST'
    sock.puts "<REQ LIST>"
    output = ''
    loop do
      break if output == '<REP LIST END>'
      output = sock.gets.chomp
      if output.split()[0] != '<REP'
        output[-1] = ''
        output[0] = ''
        output_array = output.split
        puts "  #{output_array[0]}. #{output_array[1]} -- #{output_array[2]} bytes"
        puts "  Signature: #{output_array[3]}"
      end
    end
  
  when 'GET'
    run_get command.split()[1]
    
  when 'exit'
    sock.puts ''
    puts 'TERMINATING CONNECTION'
    abort
    
  when 'help'
    puts "  Commands:"
    puts "  SEED 'filename' 'description'"
    puts "  LIST"
    puts "  GET 'filename'"
    puts "  exit"
    puts "  help"
  
  else 
    puts "  Improper command -- #{command}"
  end
  
end
