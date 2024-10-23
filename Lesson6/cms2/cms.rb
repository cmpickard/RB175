require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

FILETYPES = ['.txt', '.md']

def get_files
  dir = Dir.new(@root)
  dir.children
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(content)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(content)
end

def load_file_content(file_path)
  content = File.read(file_path)
  case File.extname(file_path)
  when '.md'
    erb render_markdown(content)
  when '.txt'
    content
  end
end

def check_doc_name(name)
  if name == "" || name.nil?
    "A name is required"
  elsif !FILETYPES.include?(name.match(/\..+/)[0])
    "Name of file must end in '.txt' or '.md'"
  end
end

def check_signed_in
  if @username != "admin"
    session[:message] = "You must be signed in to do that"
    redirect "/"
  end
end

def cms_create(name, content)
  File.write("#{data_path}/#{name}", content)
end

def cms_delete(name)
  File.delete("#{data_path}/#{name}")
end

def sign_in(username)
  session[:signed_in] = true
  session[:username] = username
  session[:message] = "Welcome, #{username}!"
end

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

before do
  @root = data_path
  @files = get_files
  @username = session[:username]
end

# homepage
get '/' do
  erb :index
end

# load login page
get '/login' do
  erb :login
end

# attempt to login user
post '/login' do
  username = params[:username]
  password = params[:password]
  users = YAML.load(File.read("./users.yaml"))

  if users.keys.include?(username) && !password.nil? && 
     BCrypt::Password.new(users[username]) == password
    sign_in(username)
    redirect '/'
  else
    session[:message] = "Invalid credentials"
    erb :login
  end
end

get '/logout' do
  session[:signed_in] = nil
  session[:username] = nil
  session[:message] = "You have been signed out"
  redirect '/login'
end

# load the new doc page
get '/new' do
  check_signed_in
  erb :new_doc
end

# create a new doc
post '/new' do
  check_signed_in
  @name = params[:name]
  @content = params[:text]
  error = check_doc_name(@name)
  if 
    session[:message] = error
    erb :new_doc
  else
    cms_create(@name, @content)
    session[:message] = "#{@name} has been created"
    redirect "/"
  end
end

# retrieves file
get '/:filename' do
  filename = params[:filename]
  file_path = "#{@root}/#{filename}"

  if @files.include?(filename)
    headers["Content-Type"] = "text/plain" if File.extname(file_path) == '.txt'
    load_file_content(file_path)
  else
    session[:message] = "'#{filename}' does not exist"
    redirect '/'
  end
end

# submits changes to file
post "/:filename" do
  check_signed_in
  filename = params[:filename]
  file_path = "#{@root}/#{filename}"
  new_content = params[:text]
  File.write(file_path, new_content)
  session[:message] = "#{filename} has been updated"
  redirect '/'
end

# edit page for file
get '/:filename/edit' do
  check_signed_in
  @filename = params[:filename]
  file_path = "#{@root}/#{@filename}"
  @contents = load_file_content(file_path)
  erb :edit
end

# delete a file
get '/:filename/delete' do
  check_signed_in
  filename = params[:filename]
  cms_delete(filename)
  session[:message] = "#{filename} has been deleted"
  redirect "/"
end