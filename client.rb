require 'socket'
require 'digest'

puts "Client Side File Sharing"
puts "Program commands:\n"
puts "Create tracker;"
puts "createtracker 'filename' 'description' ipaddress portnumber"
puts "Update Tracker:"
puts "updatetracker 'filename' startbytes endbytes"
puts "List Files available to download:"
puts "REQ LIST"
puts "Request a file:"
puts "GET 'filename'"

sock = TCPSocket.open('localhost', 8686)

loop do
  puts "enter command:"
  command = gets.chomp
  case command.split()[0]
  when 'createtracker'
    #createtracker filepath desc yourip yourport
    input = command.split
    command = "<createtracker #{input[1]} #{File.size(input[1])} #{input[2]} #{Digest::MD5.file(input[1]).hexdigest} #{input[3]} #{input[4]}>"
    
    sock.print command
    line =s.gets
    puts line
  end
end
