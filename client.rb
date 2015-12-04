require 'socket'
require 'digest'
require 'ipaddress'
require 'thread'
require 'thwait'

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
  #puts "in update"
  sock = TCPSocket.open(read_config('serverip'), read_config('serverport'))
  #puts "<updatetracker #{file_name} #{start_bytes} #{end_bytes} #{ipaddress} #{port}>"
  sock.puts "<updatetracker #{file_name} #{start_bytes} #{end_bytes} #{ipaddress} #{port}>"
  msg = sock.gets.chomp
  #puts msg
  if msg == "<updatetracker #{file_name} succ>" 
    #puts "  #{file_name}.track updated"
  elsif msg == "<updatetracker #{file_name} ferr>"
    puts "  No tracker for #{file_name}"
  else
    puts "  updatetracker failed for #{file_name}"
  end
end

def run_get(tracker)
  # Get information about peers
  log = File.open("log.txt", 'w')
  sock = TCPSocket.open(read_config('serverip'), read_config('serverport'))
  sock.puts "<GET #{tracker}>"
  #puts "sent request"
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
    #puts "seederarray: #{seederarray}"
    seederarray.each do |q|
	    seedertimes.push(q.split()[0])
    end
    seedertimes.sort
    log.puts "times: #{seedertimes}"
    log.puts "seederarray #{seederarray}"
    #seederheap = Maxheap.new(seederarray[].split()[0])->new_heap
    chunksize = read_config('chunksize').to_i
    count=0
    until seederchunks.length > (filesize.to_f / chunksize.to_f).ceil do
      seederarray.each do |n|
      #log.puts n.split()[0].class
      #log.puts seedertimes.last.class
        if n.split()[0] == seedertimes.last
			#log.puts "inside comparison"
			seederchunks[count] = n.split()[1,2]
			#log.puts "st: #{seedertimes}"
			#log.puts "n: #{n.split()[1,2]}"
			#log.puts "sc: #{seederchunks}"
			seedertimes.unshift seedertimes.pop
			count+=1
			
			    
	    end
		#log.puts "seederchunks : #{seederchunks}"
	  end
    end
    
    log.puts "seederarray: #{seederarray}"
    log.puts "seederchunks: #{seederchunks}"
    until seederchunks.length == (filesize.to_f / chunksize.to_f).ceil
		seederchunks.pop
	end
    log.puts "seederchunkslength: #{seederchunks.length}"
    # Create thread to download from each seeder
    #semaphore = Mutex.new
    thr = []
    seederarray.map! { |s|
      thr << Thread.new {
      #semaphore.synchronize{
      log.puts "thread opened"
        ip = s.split()[1]
        port = s.split()[2]            
        iter = 0
        log.puts s
        #log.puts seederchunks[iter]
        #log.puts "outside: #{seederchunks[iter][0]} ? #{ip}"
		#log.puts "outside: #{seederchunks[iter][1]} ? #{port}"
        #log.puts seederchunks.length
        #log.puts seederchunks.length.class
        #log.puts "num chunks: #{seederchunks.length}"
        until iter >= seederchunks.length do
			#log.puts "inside until"
			log.puts "#{iter}: #{seederchunks[iter]}"
          if (seederchunks[iter][0] == ip) && (seederchunks[iter][1] == port) #AND Dir["./Files/#{filename}.part#{iter}"].size == 0
            data = ''   
            log.puts "#{iter}: inside ifcheck"         
            begin
			log.puts "#{iter}: inside begin"
              inc_sock = TCPSocket.open(ip, port)
              log.puts "#{iter} sock opened"
              inc_sock.puts "#{filename.chomp} #{chunksize * iter} #{chunksize}"
              puts "Requesting bytes #{chunksize * iter} up to #{chunksize * iter + chunksize} of #{filename.chomp} from #{ip}:#{port}"
              data = inc_sock.read
            rescue
              puts "rescued"
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
            file = File.open("./Files/#{filename.chomp}.part#{iter}", 'w')
            file.print data
            file.close
            inc_sock.close
            updatetracker(filename.chomp, 0, (chunksize * iter + chunksize < filesize ? chunksize * iter + chunksize : filesize), read_config("ip"), read_config("port"))
          end
          #log.puts "iter #{iter}, other #{seederchunks.length}"
          iter += 1
        end
        #s.replace("finished")
        #seederarray[saindex] = s
        #log.puts "s: #{s}"
        #log.puts "seederarray: #{seederarray}"
      #}
      
      log.puts "thread closed"
      }
      thr.each {|t| t.join}
      #sleep 1
    }
    
    
    
    
	ThreadsWait.all_waits(*thr)
    #sleep 20
    # Loop until all parts are had
 #  complete = false
   
 #   until complete do
 #     complete = true
 #     log.puts "seederarray: #{seederarray}"
 #     seederarray.each do |v|
 #       if v[0] != "finished"
 #         complete = false
 #       end
 #     sleep 1
 #     end
  #    puts complete
 #   end
    
    puts "Constructing File: #{filename.chomp}"
    fcount= 0
    until fcount > (seederchunks.length-1) do
      File.open("./Files/#{filename.chomp}", 'a') { |f| f.print File.binread("./Files/#{filename.chomp}.part#{fcount}") }
      File.delete("./Files/#{filename.chomp}.part#{fcount}")
      fcount += 1
    end
    filepath = "./Files/#{filename}".chomp
    updatetracker(filename.chomp, 0, File.size(filepath), read_config('ip'), read_config('port'))
  else 
    puts " GET failed for #{command.split()[1]}"
  end
  puts "Done Constructing File"
  log.close
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
        #puts "message received #{message}"
        
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
