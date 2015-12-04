# cs5600fs
File Sharing Application for CS5600
Team members: 	Brian Catanzaro, Harrison Reighard, Zachery Brinkley
server.rb is the server program and is run from this directory, all of the clients have their own client.rb that they run from their own folder
Client1 has the small file cpe.pdf
Client2 has the larger file banf.jpg
Before starting no other clients should have anything in the files folder
Before starting the Torrents folder in the main directory should be empty
Make sure that each client has a different port set in their config or it will conflict
To run the script simply type 

ruby RunTest.rb

into the terminal at the directory
Clients 1 and 2 should begin seeding and 3-8 will start downloading
then 9-13 will start downloading a short time after

