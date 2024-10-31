=begin
CREATE TABLE airlines (
  id serial PRIMARY KEY,
  name text NOT NULL
);

CREATE TABLE flights (
    id serial PRIMARY KEY,
    flight_num int NOT NULL CHECK (flight_num BETWEEN 1000 AND 9999),
    destination text NOT NULL,
    airline_id int NOT NULL REFERENCES airlines(id) ON DELETE CASCADE,
    departure_time timestamp
  );

INSERT INTO airlines (name)
  VALUES ('Delta'), ('American'), ('Southwest'), ('United');

INSERT INTO flights (flight_num, destination, airline_id, departure_time)
  VALUES (1010, 'Tulsa', 1, '2025-12-10 04:05:00'),
         (1098, 'Dallas', 1, '2024-11-12 12:00:00'),
         (9912, 'New York', 2, '2024-11-30 15:35:00'),
         (7075, 'San Francisco', 3, '2025-01-31 11:45:00');
=end

require 'pg'
require 'date'
require 'logger'


class FlightDatabase
  def initialize(logger)
    @logger = logger
    @db = PG.connect(dbname: 'flights')
  end

  def execute_sql(statement, *params)
    @logger.info("#{statement} #{params}")
    @db.exec_params(statement, params)
  end

  def find_airline_id(airline)
    statement = <<~SQL
    SELECT id FROM airlines
      WHERE name = $1;
    SQL
    execute_sql(statement, airline)
  end

  def get_flight(id)
    statement = <<~SQL
      SELECT airlines.name, flights.flight_num,
             flights.departure_time, flights.destination, flights.id
        FROM flights 
        JOIN airlines 
          ON flights.airline_id = airlines.id
        WHERE flights.id = $1
    SQL
    result = execute_sql(statement, id)
    result.first
  end

  def all_flights
    statement = <<~SQL
      SELECT airlines.name, flights.flight_num,
             flights.departure_time, flights.destination, flights.id
        FROM flights 
        JOIN airlines 
          ON flights.airline_id = airlines.id
        ORDER BY flights.departure_time;
    SQL
    result = execute_sql(statement)

    result.map do |flight|
      date = DateTime.parse(flight["departure_time"])
      { airline: flight["name"], flight_num: flight["flight_num"].to_i,
        departure: date, destination: flight["destination"],
        id: flight["id"].to_i }
    end
  end

  def add_new_flight(flight_num, destination, airline, departure)
    airline_id = find_airline_id(airline).first['id'].to_i
    statement = <<~SQL
      INSERT INTO flights (flight_num, destination, airline_id, departure_time)
      VALUES ($1, $2, $3, $4);
    SQL

    execute_sql(statement, flight_num, destination, airline_id, departure)
  end

  def edit_flight(id, flight_num, destination, airline, departure)
    airline_id = find_airline_id(airline).first['id'].to_i
    statement = <<~SQL
      UPDATE flights 
        SET flight_num = $1,
            destination = $2,
            airline_id = $3,
            departure_time = $4
        WHERE id = $5;
    SQL

    execute_sql(statement, flight_num, destination, airline_id, departure, id)
  end
end

# FlightDatabase.new(Logger.new(STDOUT)).all_flights