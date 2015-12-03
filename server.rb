require 'socket'
require 'ipaddress'

# Open server on port 8686
server = TCPServer.open 8686
if !Dir.exist? 'Torrents' 
  Dir.mkdir 'Torrents'
end

puts "LISTENING ON PORT 8686 AT #{Time.now.to_i}"

# Continually listen for incoming connection requests
loop do
  # On each request spawn a listener thread
  Thread.start(server.accept) do |client|
    sock_domain, remote_port, remote_hostname, remote_ip = client.peeraddr
    puts "#{remote_ip}:#{remote_port} -- CONNECTION ESTABLISHED"
    until client.closed?
      command_phrase = client.gets.chomp
      command_phrase[0] = ''
      command_phrase[-1] = ''
      command = command_phrase.split
          
      # Parse command
      case command[0]
      
      when 'createtracker'
        # createtracker filename filesize description md5 ip-address port-number
        puts "#{remote_ip}:#{remote_port} -- CREATETRACKER #{command[1]} INIT"
        begin
          if File.exist? "./Torrents/#{command[1]}.track"
            # Disallow duplicate trackers
            client.puts '<createtracker ferr>'
            puts "#{remote_ip}:#{remote_port} -- CREATETRACKER #{command[1]} FAIL"
          else
            # Create the new tracker file
            new_tracker = File.new "./Torrents/#{command[1]}.track", 'w'
            new_tracker.puts "Filename: #{command[1]}"
            new_tracker.puts "Filesize: #{command[2]}"
            new_tracker.puts "Description: #{command[3]}"
            new_tracker.puts "MD5: #{command[4]}"
            new_tracker.puts ''
            new_tracker.puts "# Begin seeding peers"
            new_tracker.puts "#{command[5]}:#{command[6]}:0:#{command[2]}:#{Time.now.to_i}"
            new_tracker.close

            client.puts '<createtracker succ>'
            puts "#{remote_ip}:#{remote_port} -- CREATETRACKER #{command[1]} SUCCESS" 
          end
        rescue
          puts $!.message
          # On error remove file to prevent malformed trackers
          if File.exist?  "./Torrents/#{command[1]}.track"
            File.delete "./Torrents/#{command[1]}.track"
          end
          client.puts '<createtracker fail>'
          puts "#{remote_ip}:#{remote_port} -- CREATETRACKER #{command[1]} FAIL"
        end

      when 'updatetracker'
        # updatetracker filename start_bytes end_bytes ip-address port-number
        max_size = 0
        begin
          
          puts "#{remote_ip}:#{remote_port} -- UPDATETRACKER #{command[1]} INIT"
          
          if !File.exist? "./Torrents/#{command[1]}.track"
            # Can't update nonexistant trackers
            client.puts "<updatetracker #{command[1]} ferr>"
          else
            # Copy contents of old tracker to new one
            File.open("./Torrents/#{command[1]}.track.tmp", 'w') do |update_tracker|
              File.foreach("./Torrents/#{command[1]}.track") do |line|
                # Given the ip (line.split(':')[0]) and the port (line.split(':')[0]) are the same, do not rewrite line
                if !((line.split(':')[0] == command[4]) && (line.split(':')[1] == command[5]))
                  # Write all lines save those targeting updated IP
                  update_tracker.puts line
                end
                if max_size == 0 and line.split(':')[0] == "Filesize"
                  max_size = line.split(': ')[1].to_i
                end
              end
              #puts max_size

              # Bounds checking
              if command[2].to_i < 0
                command[2] = '0'
              elsif command[2].to_i > max_size
                command[2] = "#{max_size}"
              end
              if command[3].to_i > max_size
                command[3] = "#{max_size}"
              elsif command[3].to_i < command[2].to_i
                command[3] = command[2]
              end
              
              # Append new information to tracker file and delete old tracker
              update_tracker.puts "#{command[4]}:#{command[5]}:#{command[2]}:#{command[3]}:#{Time.now.to_i}"
               #File"./Torrents/#{command[1]}.track"
              File.delete "./Torrents/#{command[1]}.track"
            end
            # Rename new tracker
            File.rename "./Torrents/#{command[1]}.track.tmp", "./Torrents/#{command[1]}.track"
            client.puts "<updatetracker #{command[1]} succ>"
            puts "#{remote_ip}:#{remote_port} -- UPDATETRACKER #{command[1]} SUCCESS"
          end
        rescue 
          # On error remove any tmp files to prevent malformed trackers
          if File.exist? "./Torrents/#{command[1]}.track.tmp"
            File.delete "./Torrents/#{command[1]}.track.tmp"
          end
          client.puts "<updatetracker #{command[1]} fail>"
          puts "#{remote_ip}:#{remote_port} -- UPDATETRACKER #{command[1]} FAIL"
        end

      when 'REQ'
        # REQ LIST
        if command[1] != 'LIST'
          client.puts "Improper command -- #{command_phrase}"
          break
        end
        
        puts "#{remote_ip}:#{remote_port} -- REQ LIST"
        
        files = Dir.entries 'Torrents'
        trackers = []
        for f_name in files do
          if f_name.split('.')[-1] == 'track'
            trackers.push f_name
          end
        end
        client.puts "<REP LIST #{trackers.length}>"
        file_num = 1
        trackers.each do |f_name|
          size = ''
          md5 = ''
          File.foreach("./Torrents/#{f_name}") do |line|
            if line.split(':')[0] == 'Filesize'
              size = line.split(': ')[1]
              size[0] = ''
            elsif line.split(':')[0] == 'MD5'
              md5 = line.split(': ')[1]
              md5[0] = ''
            end
            break if md5 != '' and size != ''
          end
          
          client.puts "<#{file_num} #{f_name} #{size.chomp} #{md5.chomp}>"
          file_num += 1
        end
        client.puts '<REP LIST END>'

      when 'GET'
        puts "#{remote_ip}:#{remote_port} -- GET #{command[1]} INIT"
        # GET filename.track
        if File.exist? "./Torrents/#{command[1]}"
          md5 = ''
          bad_lines = []
          # Get content of file
          File.foreach("./Torrents/#{command[1]}") do |line|
            if line.split(':')[0] == 'MD5'
              # Save md5 for protocl
              md5 = line.split(': ')[1]
            elsif IPAddress.valid?(line.split(':')[0]) or line.split(':')[0] == 'localhost'
              # Check and make sure connections are still valid
              ip = line.split(':')[0]
              port = line.split(':')[1]
              begin
                print "Testing #{ip}:#{port} -- "
                sock = TCPSocket.open(ip, port)
                sock.close
                puts 'PASSED'
              rescue
                puts 'FAILED'
                bad_lines.push "#{ip}:#{port}"
              end
            end
          end
          
          # Remove any invalid connections
          if !bad_lines.empty?
            puts "RECONSTRUCTING #{command[1]}"
            # Copy contents of old tracker to new one
            File.open("./Torrents/#{command[1]}.tmp", 'w') do |update_tracker|
              File.foreach("./Torrents/#{command[1]}") do |line|
                if !bad_lines.include? "#{line.split(':')[0]}:#{line.split(':')[1]}"
                  # Write all lines save those targeting updated IP
                  update_tracker.puts line
                end
              end
              # Delete old tracker
              File.delete "./Torrents/#{command[1]}"
            end
            # Rename new tracker
            File.rename "./Torrents/#{command[1]}.tmp", "./Torrents/#{command[1]}"
            client.puts "<updatetracker #{command[1]} succ>"
          end
          
          # Send info
          client.puts '<REP GET BEGIN>'
          contents = File.read "./Torrents/#{command[1]}"
          client.puts "<#{contents.chomp}>"
          client.puts "<REP GET END #{md5.chomp}>"
          puts "#{remote_ip}:#{remote_port} -- GET SUCCESS"
        else
          client.puts '<GET INVALID>'
          puts "#{remote_ip}:#{remote_port} -- GET FAILED"
        end
      end
      
      # Sleep to save CPU time
      sleep(1.0/10.0)
    end
    puts "CONNECTION CLOSED -- #{remote_ip}:#{remote_port}"
  end
end

