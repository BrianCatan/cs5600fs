require 'socket'
require 'digest'
require 'ipaddress'

# First time launch file creation
if !Dir.exist? 'Files' 
  Dir.mkdir 'Files'
end

#check for config file
if !File.exist? 'client.config'
  config = File.new "client.config", 'w'
  config.puts "ip: localhost"
  config.puts "port: 8687"
  config.puts "serverip: localhost"
  config.puts "serverport: 8686"
  config.puts "chunksize: 1024"
  config.close
end

#Read config file method
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
  sock.puts "<updatetracker #{file_name} #{start_bytes} #{end_bytes} #{ipaddress} #{port}>"
  msg = sock.gets.chomp
  if msg == "<updatetracker #{file_name} succ>" 
    puts "  #{file_name}.track updated"
  elsif msg == "<updatetracker #{file_name} ferr>"
    puts "  No tracker for #{file_name}"
  else
    puts "  updatetracker failed for #{file_name}"
  end
end

# Create thread to manage file requests from other peers
server = TCPServer.open(read_config('port'))
Thread.new {
  loop {
    begin
      Thread.start(server.accept) do |client|
        message = client.gets
        message = message.split()
        if (message[1].to_i + message[2].to_i) > File.size("./Files/#{message[0]}")
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
    # Get information about peers
    sock.puts "<GET #{command.split()[1]}>"
    input = ''
    filename = ''
    filesize = 0
    md5 = ''
    ip = ''
    port = ''
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
        seederarray[index] = "#{ip} #{port}"
        index+=1
      end
    end
    
    if input.split()[3] == "#{md5.chomp}>"
      # Contact peer for file
      seederchunks = Array.new
      chunksize = read_config('chunksize').to_i
      count=0
      until seederchunks.size == (filesize.to_f / chunksize.to_f).ceil do
        seederchunks[count] = seederarray[count%index]
        count+=1
      end
      
      # Create thread to download from each seeder
      seederarray.each do |s|
        Thread.new {
          seeder = s
          ip = seeder.split()[0]
          port = seeder.split()[1]            
          iter = 0
          puts "num chunks: #{seederchunks.size}"
          until iter > seederchunks.size do
            if seederchunks[iter] == "#{ip} #{port}"
              inc_sock = TCPSocket.open(ip, port)
              inc_sock.puts "#{filename.chomp} #{chunksize * iter} #{chunksize}"
              puts "Requesting bytes #{chunksize * iter} up to #{chunksize * iter + chunksize} of #{filename.chomp} from #{ip}:#{port}"
              data = inc_sock.read
              if data.size > chunksize
                data = data[0, chunksize]
              end
              file = File.open("./Files/#{filename.chomp}.part#{iter}", 'wb')
              file.print data
              file.close
              inc_sock.close
            end
            iter += 1
          end
          print "ptpterminal: "
          count = 0
          until count == iter do
            File.open("./Files/#{filename.chomp}", 'a') { |f| f.print File.binread("./Files/#{filename.chomp}.part#{count}") }
            File.delete("./Files/#{filename.chomp}.part#{count}")
            count += 1
          end
        }
      end

      #updatetracker filename, 0, File.size("./Files/#{filename}"), read_config('ip'), read_config('port')
    else 
      puts '  GET failed for #{command.split()[1]}'
    end
    
  when 'exit'
    sock.puts ''
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
