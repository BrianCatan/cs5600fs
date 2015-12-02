require 'pty'

# Start the server
server = Thread.new {
  PTY.spawn "ruby server.rb" do |r, w, p|
    loop { puts "server: #{r.gets}" }
  end
}
sleep 1

# Start the first two clients and begin seeding
client1 = Thread.new {
  PTY.spawn "cd Client1 && ruby client.rb" do |r, w, p|
  
    client_listener = Thread.new { 
      loop { puts "client1: #{r.gets}" }
    }
    sleep 1
  
    w.puts 'SEED net.jpg an_icon'
  end
}
sleep 1

client2 = Thread.new {
  PTY.spawn "cd Client2 && ruby client.rb" do |r, w, p|
  
    client_listener = Thread.new { 
      loop { puts "client2: #{r.gets}" }
    }
    sleep 1
    w.puts 'SEED southpark.mp4 an_episode_of_southpark'
    
  end
}

sleep 15

# After 30 seconds launch clients 3-8
i = 3
until i > 8 do
  eval("
    client#{i} = Thread.new {
      PTY.spawn 'cd Client#{i} && ruby client.rb' do |r, w, p|
        client_listener = Thread.new {
          loop { puts 'client#{i}: ' + r.gets }
        }
        sleep 1
        w.puts 'LIST'
        sleep 1
        w.puts 'GET net.jpg.track'
        sleep 1
        #w.puts 'GET southpark.mp4.track'
      end
    }
  ")
  i += 1
end

sleep 1000

server.exit
client1.exit
client2.exit
i = 3
until i > 8 do
eval("client#{i}.exit")
end
