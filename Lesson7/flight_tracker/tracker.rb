require 'sinatra'
require 'tilt/erubis'
require 'date'
require 'logger'
require "sinatra/reloader"

require_relative './flight_database.rb'

configure do
  enable :sessions
  also_reload("flight_database.rb")
  set :erb, :escape_html => true
end

before do
  @storage = FlightDatabase.new(Logger.new(STDOUT))
end

helpers do
  INT_MONTHS = { 1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April',
                 5 => 'May', 6 => 'June', 7 => 'July', 8 => 'August', 
                 9 => 'September', 10 => 'October', 11 => 'November', 
                 12 => 'Decemeber' }

  def format_departure(departure)
    day = departure.day
    month = INT_MONTHS[departure.month]
    year = departure.year
    "#{month} #{day}, #{year}"
  end
end

def validate_flight_info(destination, flight_num)
  if !(1000..9999).cover?(flight_num)
    "Flight number must be a 4-digit value"
  elsif destination == '' || destination.length > 50
    "Destination must be between 1 and 50 characters"
  end
end

get "/" do
  @flights = @storage.all_flights
  erb :home
end

get "/flight/new" do
  erb :new
end

post "/flight/new" do
  @date = params[:date]
  @time = params[:time]
  datetime = @date + " " + @time
  @destination = params[:destination]
  @airline = params[:airline]
  @flight_num = params[:flight_num].to_i

  error = validate_flight_info(@destination, @flight_num)
  if error
    session[:message] = error
    erb :new
  else
    @storage.add_new_flight(@flight_num, @destination, @airline, datetime)
    session[:message] = "Flight has been successfully added"
    redirect "/"
  end
end

get "/flight/:id/edit" do
  @id = params[:id].to_i
  flight_info = @storage.get_flight(@id)
  @airline = flight_info['name']
  @flight_num = flight_info['flight_num']
  datetime = DateTime.parse(flight_info['departure_time'])
  @date = datetime.to_s[0,10]
  @time = datetime.to_s[11,8]
  @destination = flight_info['destination']
  erb :edit
end

post "/flight/:id/edit" do
  @id = params[:id].to_i
  @date = params[:date]
  @time = params[:time]
  datetime = @date + " " + @time
  @destination = params[:destination]
  @airline = params[:airline]
  @flight_num = params[:flight_num].to_i

  error = validate_flight_info(@destination, @flight_num)
  if error
    session[:message] = error
    erb :edit
  else
    @storage.edit_flight(@id, @flight_num, @destination, @airline, datetime)
    session[:message] = "Flight has been successfully edited"
    redirect "/"
  end
end

