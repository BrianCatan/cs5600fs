require 'pty'

# Start the server
server = Thread.new {
  PTY.spawn "ruby server.rb" do |r, w, p|
    loop { puts "server: #{r.gets}" }
  end
}
sleep 1

# Start the first two clients and begin seeding; closes them after 2 minutes
client1 = Thread.new {
  PTY.spawn "cd Client1 && ruby client.rb" do |r, w, p|
  
    client_listener = Thread.new { 
      loop { puts "client1: #{r.gets}" }
    }
    sleep 1
  
    w.puts 'SEED cpe.pdf an_filen'
    sleep 120
    w.puts 'exit'
  end
}
sleep 1

client2 = Thread.new {
  PTY.spawn "cd Client2 && ruby client.rb" do |r, w, p|
  
    client_listener = Thread.new { 
      loop { puts "client2: #{r.gets}" }
    }
    sleep 1
    w.puts 'SEED banf.jpg an_park'
    sleep 120
    w.puts 'exit'
  end
}

sleep 15

# After 15 seconds launch clients 3-8; minute and a half clients 9-13
i = 3
until i > 13 do
  eval("
    client#{i} = Thread.new {
      PTY.spawn 'cd Client#{i} && ruby client.rb' do |r, w, p|
        client_listener = Thread.new {
          loop { puts 'client#{i}: ' + r.gets }
        }
        sleep 1
        w.puts 'LIST'
        sleep 1
        w.puts 'GET cpe.pdf.track'
        sleep 1
        w.puts 'GET banf.jpg.track'
      end
    }
  ")
  i += 1
  if i == 9
    sleep 90
  end
end

sleep 10000

server.exit
client1.exit
client2.exit
i = 3
until i > 13 do
eval("client#{i}.exit")
end
