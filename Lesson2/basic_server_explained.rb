require "socket"

server = TCPServer.new("localhost", 3003) # creates TCPServer object

loop do
  client = server.accept # creates TCPSocket object, assigns to new var

  request_line = client.gets # calls IO#gets to get a line from the input stream
  next if !request_line || request_line =~ /favicon/ #error handling for Chrome 
  # when Chrome connects to a server it immediately asks what image to use for the
  # tab part of the tab -- that's called a favicon. Google requests a "favicon.ico"
  # this line basically says: listen in for more requests if the last request return nil or a favicon request.
  puts request_line #outputs to *my* console the HTTP request received

  client.puts "HTTP/1.1 200 OK" # calls IO#puts on the TCPSocket which sends a
  # plaintext string back to chrome -- recall, HTTP is just plaintext
  client.puts "Content-Type: text/plain\r\n\r\n" #optional header plus required
  # space between header/status line and body

  client.puts request_line # this simply echos the browser's original request back to the browser
  client.puts # the protocol expects a blank line between requests
  client.close # closes the connection at end of loop cycle
end