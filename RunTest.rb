require 'pty'

server = Thread.new {
  PTY.spawn "ruby server.rb" do |r, w, p|
    loop { puts "server: #{r.gets}" }
  end
}

sleep 1

PTY.spawn "ruby client.rb" do |r, w, p|
  
  client_listener = Thread.new {
    loop { puts "client1: #{r.gets}" }
  }
  sleep 1
  
  w.puts 'LIST'
end

sleep 10

server.exit


#server = Thread.new {
 # IO.popen("ruby server.rb") do |io|
 #   io.each do |line|
 #     print "Server: #{line}"
 #   end
#  end
#}

#client = Thread.new {
#  `cd Client1`
#  client_pipe = IO.popen("ruby client.rb")
#  while (line = client_pipe.gets)
#    print "Client: #{line}"
#  end
#}

#server.join
#client.join
