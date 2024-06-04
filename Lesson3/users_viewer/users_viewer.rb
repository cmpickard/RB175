require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'yaml'

def count_interests(data)
  data.values.map { |hash| hash[:interests] }.flatten.count
end

before do
  #load yml
  file = File.read("data/users.yml")
  @user_data = YAML.load(file)
  @users = @user_data.keys.map(&:to_s).map(&:capitalize)
  @interests = count_interests(@user_data)
end

get "/" do
  erb :home
  # @user_data.to_s
end

get "/user/:name" do
  @name = params["name"]
  sym_name = @name.downcase.to_sym
  data = @user_data[sym_name]
  @email_str = data[:email]
  @interests_arr = data[:interests]
  @other_users = @users.clone.delete_if { |el| el == @name }
  erb :user
end

not_found do
  redirect "/"
end