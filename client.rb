require 'socket'
require 'digest'

puts "Client Side File Sharing"
puts "Program commands:\n"
puts "Create tracker;"
puts "createtracker 'filename' filesize(optional) 'description' md5(optional) ipaddress portnumber"
puts "Update Tracker:"
puts "updatetracker 'filename' startbytes endbytes"
puts "List Files available to download:"
puts "REQ LIST"
puts "Request a file:"
puts "GET 'filename'"

s = TCPSocket.open('localhost', 8686)

loop do
  puts "enter command:"
  gets command
  case command[0]
  when 'createtracker'
    
    command = '<createtracker'
    puts "enter file name"
    gets command[1]
    command[2]=size(command[1])
    
    puts "Enter description"
    gets command[3]
    command[4]=Digest::MD5.file(filename).hexdigest
    puts "Enter IP of host:"
    gets command[5]
    puts "Enter port number of host:"
    gets command[6]
    
    s.send command
    puts s.recv
end

