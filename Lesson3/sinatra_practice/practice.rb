require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'


get '/' do
  @words = ["a", "b", "c"]
  erb :practice
end

get '/redirect' do
  location = "/new"
end