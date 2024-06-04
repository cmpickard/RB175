# TODO
=begin
USER SIGN UP FORM
(i) No account? Sign up -- button
(ii) new view template for creating user account -- need both name and password
(iii) verification for username -- reject duplicates
(iv) verification of password -- reject empty
(v) update users.yml with new user
(vi) sign them in immediately?


=end


require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require "sinatra/content_for"
require "rack"
require "redcarpet"
require 'yaml'
require 'bcrypt'

FILETYPES = ['md', 'txt']

def create(file_name, contents="")
  File.write("#{@pattern}/#{file_name}", contents)
end

def cannot_find(file)
  !@file_names.include?(file)
end

def validate(file_name)
  if file_name == "" || file_name.nil?
    "File must have non-empty name"
  elsif file_name =~ /\.(#{FILETYPES.join('|')})/ && file_name.count('.') == 1
   nil
  elsif file_name.count('.') > 1
    "Name cannot include a period (except for the extension)"
  else
    "File name must have .#{FILETYPES.join(' or .')} extension"
  end
end

def signed_in?
  session[:signed_in]
end

def markdowner(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

# called by routes that need to load a file's content
def load_content
  contents = File.read("#{@pattern}/#{@file_name}")
  if @file_name[-3..-1] == ".md"
    contents = markdowner(contents)
    headers["Content-Type"] = "text/html"
    erb contents
  elsif @file_name[-4..-1] == ".txt"
    headers["Content-Type"] = "text/plain"
    contents
  end
end

def load_users
  if ENV["RACK_ENV"] == "test"
    YAML.load_file("test/users.yml")
  else
    YAML.load_file("users.yml")
  end
end

def write_users(user_hash)
  if ENV["RACK_ENV"] == "test"
    File.write("test/users.yml", user_hash.to_yaml)
  else
    File.write('users.yml', user_hash.to_yaml)
  end
end

def check_credentials(password)
  users = load_users
  return :invalid if users[@username] == nil
  
  if @username == 'admin' && BCrypt::Password.new(users['admin']) == password
    :admin
  elsif BCrypt::Password.new(users[@username]) == password
    :user
  else
    :invalid
  end
end

def validate_new(username, password)
  existing_users = load_users
  if username == "" || password == ""
    "Neither field can be left blank."
  elsif !existing_users[username].nil?
    "Username already in use."
  else
    nil
  end
end

def add_user
  user_hash = load_users
  new_user_password = BCrypt::Password.create(params[:password]).to_s
  user_hash[params[:username]] = new_user_password
  write_users(user_hash)
end

configure do
  enable :sessions
  set :port, 9494
end

before do
  @pattern = data_path
  @file_names = Dir.glob("#{@pattern}/*").map { |file| File.basename(file) }
end

# home page / index
get '/' do
  erb :index
end

# go to signin page
get '/users/signin' do
  erb :signin
end

get '/users/new_acct' do
  erb :new_acct
end

post '/users/new_acct' do
  @username = params[:username]
  @password = params[:password]
  error = validate_new(@username, @password)
  if error
    session[:message] = error
    erb :new_acct
  else
    add_user
    session[:message] = "New account successfully created. Please sign in."
    redirect '/users/signin'
  end
end

# sign in
post '/users/signin' do
  @username = params[:username]
  credential = check_credentials(params[:password])
  if credential != :invalid
    session[:admin] = true if credential == :admin
    session[:signed_in] = true
    session[:username] = @username
    session[:message] = "Welcome!"
    redirect '/' 
  end

  session[:message] = "Invalid credentials"
  status 422
  erb :signin
end

# sign-out
post '/users/signout' do
  session[:signed_in] = false
  session[:admin] = false
  session[:username] = ""
  session[:message] = "You have been signed out"
  redirect '/'
end


# go to page for naming a new file
get '/new' do
  if !signed_in?
    session[:message] = 'You must be signed in to create a file.'
    redirect '/'
  else
    erb :new
  end
end

# submit name for new file for CMS
post '/new' do
  @file_name = params[:file_name]
  
  redirect '/' if !signed_in?

  error = validate(@file_name)
  if error
    session[:message] = error
    erb :new
  else
    create(@file_name)
    session[:message] = "#{@file_name} has been successfully created"
    redirect '/'
  end  
end

# duplicate existing file
post '/duplicate' do
  @file_name = params[:duplicate]
  name, extension = @file_name.split('.')
  contents = File.read("#{@pattern}/#{@file_name}")
  create("#{name}_copy.#{extension}", contents)
  session[:message] = "#{@file_name} has been duplicated"
  redirect '/'
end

# load page for renaming files
get '/:file_name/rename' do
  erb :rename
end

# request to rename a file
post '/:file_name/rename' do
  @old_name = params[:file_name]
  @new_name = params[:new_name]
  error = validate(@new_name)
  if error
    session[:message] = error
  else
    contents = File.read("#{@pattern}/#{@old_name}")
    create("#{@new_name}", contents)
    File.delete("#{@pattern}/#{@old_name}")
    session[:message] = "#{@new_name} has been successfully renamed"
    redirect '/'
  end
end

# go to admin page for adding/deleting user accounts
get '/useraccts' do
  erb :useraccts
end

# add a user account
post '/useraccts' do
  add_user

  session[:message] = "Successfully added #{params[:username]} to users"
  redirect '/useraccts'
end

# delete a user from the hash of user accounts
post '/users/delete' do
  user = params[:name]
  user_hash = load_users
  if user_hash.include?(user)
    user_hash.delete(user)
    write_users(user_hash)
    session[:message] = "Successfully deleted #{user} from users"
  else
    session[:message] = "Unable to delete #{user}"
  end
  redirect '/useraccts'
end

# go to page for editing :file_name
get '/:file_name/edit' do
  if !signed_in?
    session[:message] = "You must be signed in to edit a file."
    redirect '/'
  end

  @file_name = params[:file_name]
  if cannot_find(@file_name)
    session[:message] = "#{@file_name} does not exist."
    redirect "/"
  end
  @contents = File.read("#{@pattern}/#{@file_name}")
  erb :edit
end

# submits edit for :file_name
post '/:file_name' do
  redirect '/' if !signed_in?

  File.write("#{@pattern}/#{params[:file_name]}", params[:contents])

  session[:message] = "#{params[:file_name]} has been updated."
  redirect '/'
end

# submits a delete request for :file_name
post '/:file_name/delete' do
  if !signed_in?
    session[:message] = "You must be signed in to delete a file"
    redirect '/'
  end
  @file_name = params[:file_name]
  File.delete("#{@pattern}/#{@file_name}")
  session[:message] = "#{@file_name} has been deleted"
  redirect '/'
end

# go to page for viewing :file_name
get '/:file_name' do
  @file_name = params[:file_name]
  if cannot_find(@file_name)
    session[:message] = "#{@file_name} does not exist."
    redirect "/"
  else 
    load_content
  end
end
