require 'socket'

# Open server on port 8686
server = TCPServer.open 8686
if !Dir.exist? 'Torrents' 
  Dir.mkdir 'Torrents'
end

# Continually listen for incoming connection requests
loop do
  # On each request spawn a listener thread
  Thread.start(server.accept) do |client|
    command_phrase = client.gets.chomp
    command_phrase[0] = ''
    command_phrase[-1] = ''
    command = command_phrase.split
    
    # Parse command
    case command[0]

    when 'createtracker'
      # createtracker filename filesize description md5 ip-address port-number
      begin
        if File.exist? "./Torrents/#{command[1]}.track"
          # Disallow duplicate trackers
          client.puts '<createtracker ferr>'
          puts 'Duplicate tracker'
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
        end
      rescue
        puts $!.message
        # On error remove file to prevent malformed trackers
        if File.exist?  "./Torrents/#{command[1]}.track"
          File.delete "./Torrents/#{command[1]}.track"
        end
        client.puts '<createtracker fail>'
      end

    when 'updatetracker'
      # updatetracker filename start_bytes end_bytes ip-address port-number
      begin
        if !File.exist? "./Torrents/#{command[1]}.track"
          # Can't update nonexistant trackers
          client.puts "<updatetracker #{command[1]} ferr>"
        else
          # Copy contents of old tracker to new one
          File.open("./Torrents/#{command[1]}.track.tmp", 'w') do |update_tracker|
            File.foreach("./Torrents/#{command[1]}.track") do |line|
              if line.split(':')[0] != command[4]
                # Write all lines save those targeting updated IP
                update_tracker.puts line
              end
            end
            # Append new information to tracker file and delete old tracker
            update_tracker.puts "#{command[4]}:#{command[5]}:#{command[2]}:#{command[3]}:#{Time.now.to_i}"
            File.delete "./Torents/#{command[1]}.track"
          end
          # Rename new tracker
          File.rename "./Torrents/#{command[1]}.track.tmp", "./Torrents/#{command[1]}.track"
          client.puts "<updatetracker #{command[1]} succ>"
        end
      rescue
        # On error remove any tmp files to prevent malformed trackers
        if File.exist? "./Torrents/#{command[1]}.track.tmp"
          File.delete "./Torrents/#{command[1]}.track.tmp"
        end
        client.puts "<updatetracker #{command[1]} fail>"
      end

    when 'REQ'
      # REQ LIST
      if command[1] != 'LIST'
        client.puts "Improper command -- #{command_phrase}"
      end
      
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
      # GET filename.track
      if File.exist? "./Torrents/#{command[1]}"
        md5 = ''
        File.foreach("./Torrents/#{command[1]}") do |line|
          if line.split(':')[0] == 'MD5'
            md5 = line.split(': ')[1]
          end
        end
        client.puts '<REP GET BEGIN>'
        contents = File.read "./Torrents/#{command[1]}"
        client.puts "<#{contents.chomp}>"
        client.puts "<REP GET END #{md5.chomp}>"
      end

    else client.puts "Improper command -- #{command_phrase}"
    end
    sleep(1.0/10.0)
  end
end
