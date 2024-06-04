require 'sinatra'
require 'sinatra/reloader'

before do
  @files = `ls public`.split(' ')
end

get '/' do
  @sort_order = params["sort"]
  @files = @files.reverse if @sort_order == "desc"
  erb :home
end

# get '/:file_name' do
#   @name = params["file_name"]
#   erb 
# end