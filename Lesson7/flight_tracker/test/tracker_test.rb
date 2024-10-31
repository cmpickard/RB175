ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "rack/test"

require_relative "../tracker.rb"

Minitest::Reporters.use!

class FlightTrackerTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
  end

  def teardown
  end

  def test_test
    assert_equal 0, 0
  end
end