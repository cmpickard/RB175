require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'yaml'
require 'rack'

=begin
todo:

(iv) testing
(v) sort by / view-only contact group feature?


contacts = [{ first_name: "John",
              last_name: "Juan",
              phone_num: { "(XXX)XXX-XXXX": Work },
              email: ["xxx@yahoo.com"],
              groups: ["family", "friends", "work"] 
              id: 1 },
=end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def get_contact(id)
  @contacts.select { |contact| contact[:id] == id }[0]
end

def load_contacts
  @contacts = YAML.load_file("#{@pattern}/contacts.yml")
end

def validate_new
  if already_exists?
    "Contact already exists. Go to Edit page to adjust information."
  elsif invalid_name?
    "First / last names must use only alphabetic characters."
  elsif invalid_phone?
    "Phone number must be in this format: (###)###-####"
  elsif invalid_email?
    "Email must be in this format: sample_name@host.domain"
  end
end

def already_exists?
  @contacts.any? do |contact|
    contact[:first_name].downcase == @first_name.downcase && 
    contact[:last_name].downcase == @last_name.downcase
  end
end

def invalid_name?
  @first_name =~ /[^a-z\-' \n]/i || @last_name =~ /[^a-z\-' \n]/i ||
  @first_name == ""             || @last_name == ""
end

def invalid_phone?
  !(@phone =~ /\(\d{3}\) ?\d{3}-\d{4}/)
end
  
def invalid_email?
  !(@email =~ /\w{1,}@[a-z]{1,}\.[a-z]{2,}/)
end

def add_contact
  new_contact = { first_name: @first_name, 
                  last_name: @last_name, 
                  phone_num: {@phone => @phone_type},
                  email: [@email],
                  group: @contact_group,
                  id: (@contacts[-1][:id] + 1)
                }
  @contacts << new_contact
  update_yaml
end

def update_yaml
  File.write("#{@pattern}/contacts.yml", YAML.dump(@contacts))
end

configure do
  enable :sessions
  set :port, 9494
end

before do
  @pattern = data_path
  @contacts = load_contacts
end

helpers do
  def pretty_print(key)
    case key
    when :first_name then "First name"
    when :last_name then "Last name"
    when :phone_num then "Phone number"
    when :email then "Email address"
    when :group then "Contact group"
    else
      key
    end
  end

  def format_phones(phone_hash)
    # HERE TO SWITCH k/v for phones
    phone_hash.map { |num, type| "<li><b>#{type.capitalize}</b>: #{num}</li>" }.join()
  end

  def format_emails(email_arr)
    email_arr.map { |email| "<li>#{email}</li>" }.join()
  end
end

get '/' do
  erb :home
end

get '/contacts/new' do
  erb :new
end

get '/contacts/:id' do
  id = params[:id].to_i

  @contact = get_contact(id)
  erb :contact
end

post '/contacts/new' do
  @first_name = params[:first_name]
  @last_name = params[:last_name]
  @phone = params[:phone]
  @phone_type = params[:phone_type]
  @email = params[:email]
  @contact_group = params[:contact_group]

  error = validate_new
  if error
    session[:message] = error
    erb :new
  else
    add_contact
    session[:message] = "Contact #{@first_name} #{@last_name} added!"
    redirect '/'
  end
end

get '/contacts/:id/edit' do
  @id = params[:id].to_i
  @contact = get_contact(@id)
  @first_name = @contact[:first_name]
  erb :edit
end

post '/contacts/:id/edit' do
  @id = params[:id].to_i
  @first_name = params[:first_name]
  @last_name = params[:last_name]
  @phone = params[:phone]
  @phone_type = params[:phone_type]
  @email = params[:email]
  @contact_group = params[:contact_group]

  error = validate_new
  if error
    session[:message] = error
    erb :new
  else
    # delete old contact
    @contacts = @contacts.reject { |contact| contact[:id] == params[:id].to_i }
    update_yaml
    # add new contact
    add_contact
    session[:message] = "Contact #{@first_name} #{@last_name} was updated!"
    redirect '/'
  end
end

# delete contact
get '/contacts/:id/delete' do
  @contacts = @contacts.reject { |contact| contact[:id] == params[:id].to_i }
  update_yaml
  session[:message] = "Contact successfully deleted."
  redirect '/'
end

