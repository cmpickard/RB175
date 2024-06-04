require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "sinatra/content_for"
require "rack"

# return error message for invalid list name, or nil if valid
def error_for_list_name(list_name)
  if !(1..100).cover?(list_name.size)
    "List name must be between 1 and 100 characters"
  elsif session[:lists].any? {|list| list[:name] == list_name }
    "List name must be unique"
  end
end

# return error message for invalid todo
def error_for_todo(todo_name)
  "Todo name must be between 1 and 100 characters" if !(1..100).cover?(todo_name.size)
end

def load_list(list_id)
  if list_id.to_i > session[:lists].size ||
     list_id.to_i.to_s != list_id
    session[:error] = "The specified list was not found"
    redirect "/lists"
  else
    session[:lists][list_id.to_i]
  end
end

def next_element_id(elements)
  max = elements.map { |el| el[:id] }.max || 0
  max + 1
end

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
end

helpers do
  def list_complete?(list)
    if !list[:todos].empty? && list[:todos].all? { |todo| todo[:completed] }
      "complete"
    end
  end

  def count_complete(list)
    list[:todos].count { |todo| todo[:completed] }
  end

  def count_total_todos(list)
    list[:todos].size
  end

  def sort_lists_by_completed(lists)
    lists.sort_by { |list| list_complete?(list) == "complete" ? 1 : 0 }
  end

  def sort_todos_by_completed(todos)
    todos.sort_by { |todo| todo[:completed] ? 1 : 0 }
  end

  def get_list_id_for(list)
    session[:lists].index(list)
  end

  def get_todo_id_for(todo, list)
    list[:todos].index(todo)
  end
end

get "/" do
  redirect "/lists"
end

# view all lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_element_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# edit an existing list
post "/lists/:list_id" do
  id = params[:list_id].to_i
  @list = load_list(params[:list_id])
  list_name = params[:list_id].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = params[:list_name]
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# delete a list
post "/lists/:list_id/delete" do
  idx = params[:list_id].to_i
  session[:lists].delete_at(idx)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# add a todo
post "/lists/:list_id/todos" do
  list_id = params[:list_id].to_i
  @list = load_list(params[:list_id])
  text = params[:todo].nil? ? "" : params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_element_id(@list[:todos])
    todo = { id: id, name: params[:todo], completed: false }
    @list[:todos] << todo
    session[:success] = "The todo id is #{todo[:id]}"
    redirect "lists/#{list_id}"
  end
end

# delete a todo
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @todo_id = params[:todo_id].to_i
  @list = load_list(params[:list_id])
  @list[:todos].delete_at(@todo_id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "lists/#{@list_id}"
  end
end

post '/lists/:list_id/todos/:todo_id/incomplete' do
  @list_id = params[:list_id].to_i
  @todo_id = params[:todo_id].to_i
  @list = load_list(params[:list_id])
  @list[:todos][@todo_id][:completed] = false
  session[:success] = "Todo marked incomplete"
  redirect "/lists/#{@list_id}"
end

post '/lists/:list_id/todos/:todo_id/complete' do
  @list_id = params[:list_id].to_i
  @todo_id = params[:todo_id].to_i
  @list = load_list(params[:list_id])
  @list[:todos][@todo_id][:completed] = true
  session[:success] = "Todo marked complete"
  redirect "/lists/#{@list_id}"
end

post '/lists/:list_id/todos/check_all' do
  @list_id = params[:list_id].to_i
  @todo_id = params[:todo_id].to_i
  @list = load_list(params[:list_id])
  @list[:todos].each {|todo| todo[:completed] = true }
  session[:success] = "All todos marked complete"
  redirect "/lists/#{@list_id}"
end

# render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end 

# render a particular list, using its number id
get '/lists/:list_id' do
  @list = load_list(params[:list_id])
  idx = params[:list_id].to_i
  erb :list, layout: :layout
end

get '/lists/:list_id/edit' do
  @list = load_list(params[:list_id])
  idx = params[:list_id].to_i
  erb :edit_list, layout: :layout
end