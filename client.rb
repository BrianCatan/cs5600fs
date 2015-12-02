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
        out_file = client.gets.chomp
        out_bytes = client.gets.chomp
        contents = File.open("./Files/#{out_file}", "rb") { |f| f.read(out_bytes) }
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
      end
    end
    
    if input.split()[3] == "#{md5.chomp}>"
      # Contact peer for file
      inc_sock = TCPSocket.open(ip, port)
      inc_sock.puts filename
      inc_sock.puts read_config(chunksize)
      data = inc_sock.read
      file = File.open("./Files/#{filename.chomp}", 'wb')
      file.print data
      file.close
      updatetracker filename, 0, File.size("./Files/#{filename}"), read_config('ip'), read_config('port')
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
