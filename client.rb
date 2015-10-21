require 'socket'
require 'digest'
require 'ipaddress'

# Connect to torrent server
sock = TCPSocket.open('localhost', ARGV[0].to_i)

if !Dir.exist? 'Files' 
  Dir.mkdir 'Files'
end

# Create thread to manage file requests from other peers
server = TCPServer.open(ARGV[1].to_i)
Thread.new {
  loop {
    begin
      Thread.start(server.accept) do |client|
        out_file = client.gets.chomp
        contents = File.open("./Files/#{out_file}", "rb") { |f| f.read }
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
  
  when 'createtracker'
    # createtracker filepath desc yourip yourport
    input = command.split
    size = File.size("./Files/#{input[1]}")
    md5 = Digest::MD5.file("./Files/#{input[1]}").hexdigest
    sock.puts "<createtracker #{input[1]} #{size} #{input[2]} #{md5} #{input[3]} #{input[4]}>"
    msg = sock.gets.chomp
    if msg == "<createtracker succ>" 
      puts "  #{input[1]}.track created"
    elsif msg == "<createtracker ferr>"
      puts "  Duplicate tracker for #{input[1]}"
    else
      puts "  createtracker failed for #{input[1]}"
    end
    
  when 'updatetracker'
    # updatetracker filename start_bytes end_bytes ip-address port-number
    input = command.split
    sock.puts "<updatetracker #{input[1]} #{input[2]} #{input[3]} #{input[4]} #{input[5]}>"
    msg = sock.gets.chomp
    if msg == "<updatetracker #{input[1]} succ>" 
      puts "  #{input[1]}.track updated"
    elsif msg == "<updatetracker #{input[1]} ferr>"
      puts "  No tracker for #{input[1]}"
    else
      puts "  updatetracker failed for #{input[1]}"
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
      data = inc_sock.read
      file = File.open("./Files/#{filename.chomp}", 'wb')
      file.print data
      file.close
    else 
      puts '  GET failed for #{command.split()[1]}'
    end
    
  when 'exit'
    sock.puts ''
    abort
    
  when 'help'
    puts "  Commands:"
    puts "  createtracker 'filename' 'description' 'ipaddress' 'portnumber'"
    puts "  updatetracker 'filename' 'start_bytes' 'end_bytes' 'ipaddress' 'portnumber'"
    puts "  LIST"
    puts "  GET 'filename'"
    puts "  exit"
    puts "  help"
  
  else 
    puts "  Improper command -- #{command}"
  end
  
end
