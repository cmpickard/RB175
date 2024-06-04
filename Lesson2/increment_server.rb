require "socket"

server = TCPServer.new("localhost", 3003) 

def request_splitter(request)
  method, path_and_query_str, http_v = request.split(' ') 
  path, query_str = path_and_query_str.split('?')
  query_str ||= ""
  query_hash = query_str.split('&').map{ |query| query.split('=') }.to_h
  query_bool = (query_hash["increment"] == "true")
  [query_bool, method, path, http_v]
end

current_num = 1

loop do
  client = server.accept 

  request_line = client.gets 
  next if !request_line || request_line =~ /favicon/ 
  puts request_line

  query_bool, method, path, http_v = request_splitter(request_line)
  current_num = (query_bool ? current_num + 1 : current_num - 1)
  minus_url = 'http://localhost:3003/?increment=false'
  plus_url = 'http://localhost:3003/?increment=true'

  client.puts "HTTP/1.1 200 OK" 
  client.puts "Content-Type: text/html\r\n\r\n"

  client.puts "<html>"
  client.puts "<body>"
  client.puts "<h1>The Current Number:</h1>"
  client.puts "#{current_num}"
  client.puts "<p><a href=#{minus_url}>DECREMENT</a> or <a href=#{plus_url}>INCREMENT</a></p>"
  client.puts "</body>"
  client.puts "</html>"
  client.close 
end
