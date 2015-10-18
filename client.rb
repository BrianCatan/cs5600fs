require 'socket'
require 'digest'
require 'ipaddress'

puts "Client Side File Sharing"
puts "Program commands:\n"
puts "Create tracker;"
puts "createtracker 'filename' 'description' ipaddress portnumber"
puts "List Files available to download:"
puts "REQ LIST"
puts "Request a file:"
puts "GET 'filename'"

sock = TCPSocket.open('localhost', 8686)
server = TCPServer.open(8687)

Thread.new {
  loop {
    Thread.start(server.accept) do |client|
      out_file = client.gets.chomp
      puts out_file
      contents = File.open(out_file, "rb") { |f| f.read }
      client.puts contents
      client.close
    end
  }
}

loop do
  puts "enter command:"
  command = gets.chomp
  case command.split()[0]
  when 'createtracker'
    # createtracker filepath desc yourip yourport
    input = command.split
    command = "<createtracker #{input[1]} #{File.size(input[1])} #{input[2]} #{Digest::MD5.file(input[1]).hexdigest} #{input[3]} #{input[4]}>"
    
    sock.puts command
    puts sock.gets
  when 'LIST'
    sock.puts "<REQ LIST>"
    output = ''
    loop do
      break if output == '<REP LIST END>'
      output = sock.gets
      puts output
    end
  when 'GET'
    # Get information about peers
    sock.puts "<GET #{command.split()[1]}.track>"
    input = ''
    filename = ''
    filesize = 0
    md5 = ''
    ip = ''
    port = ''
    until input.split()[2] == 'END' do
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
    
    #puts "#{filename} #{filesize} #{md5} #{ip} #{port}"
    #if input.split()[3] == md5
      # Contact peer for file
      inc_sock = TCPSocket.open(ip, port)
      inc_sock.puts filename
      data = inc_sock.read
      file = File.open("#{filename}.tmp", 'wb')
      file.print data
      file.close
   # end
  end
end
