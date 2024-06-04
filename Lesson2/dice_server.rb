require "socket"

def request_splitter(request)
  method, path_and_query_str, http_v = request.split(' ') 
  path, query_str = path_and_query_str.split('?')
  query_hash = query_str.split('&').map{ |query| query.split('=') }.to_h
  [query_hash, method, path, http_v]
end

def roll_dice(rolls, sides)
  rolls = (rolls ? rolls.to_i : 1)
  sides = (sides ? sides.to_i : 6)
  results = [] 
  rolls.times { |_| results << rand(sides) + 1 }
  results.join(", ")
end

server = TCPServer.new("localhost", 3003)

loop do
  client = server.accept

  request_line = client.gets
  next if !request_line || request_line =~ /favicon/

  query_hash, method, path, http_v = request_splitter(request_line)

  puts request_line

  client.puts "HTTP/1.1 200 OK"
  client.puts "Content-Type: text/html\r\n\r\n"
  client.puts "<html>"
  client.puts "<body>"
  client.puts "<pre>"
  client.puts method
  client.puts path
  client.puts query_hash
  client.puts "</pre>"

  client.puts "<h1> Rolls </h1>"
  rolls = roll_dice(query_hash["rolls"], query_hash["sides"])
  client.puts "<p>#{rolls}</p>"
  client.puts "</body>"
  client.puts "</html>"
  client.puts 
  client.close
end
