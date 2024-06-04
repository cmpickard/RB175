ENV["RACK_ENV"] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../contacts.rb'

class ContactsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def test_home
    get '/'
    assert_equal 200, last_response.status
  end

  def test_new_and_delete_contact
    # add new contact
    post '/contacts/new', first_name:"Jane", last_name:"Wayne", phone:"(999)999-9999", phone_type:"Work", email:"sample@gmail.com", group:"Family"
    assert_equal 302, last_response.status
    assert_equal "Contact Jane Wayne added!", session[:message]
    get last_response["Location"]
    assert_includes last_response.body, "Jane Wayne"

    # delete contact
    get '/contacts/2/delete'
    assert_equal "Contact successfully deleted.", session[:message]
    assert_equal 302, last_response.status
    get last_response["Location"]
    refute_includes last_response.body, "Jane Wayne"
  end

  def test_new_contact_bad_input
    post '/contacts/new', first_name:"Jane1", last_name:"Wayne", phone:"(999)999-9999", phone_type:"Work", email:"sample@gmail.com", group:"Family"
    assert_includes last_response.body, "First / last names must use only alphabetic characters."

    post '/contacts/new', first_name:"Jane", last_name:"Wayne1", phone:"(999)999-9999", phone_type:"Work", email:"sample@gmail.com", group:"Family"
    assert_includes last_response.body, "First / last names must use only alphabetic characters."

    post '/contacts/new', first_name:"John", last_name:"Juan", phone:"(999)999-9999", phone_type:"Work", email:"sample@gmail.com", group:"Family"
    assert_includes last_response.body, "Contact already exists. Go to Edit page to adjust information."

    post '/contacts/new', first_name:"Jane", last_name:"Wayne", phone:"(999)999", phone_type:"Work", email:"sample@gmail.com", group:"Family"
    assert_includes last_response.body, "Phone number must be in this format: (###)###-####"

    post '/contacts/new', first_name:"Jane", last_name:"Wayne", phone:"(999)999-9999", phone_type:"Work", email:"sample@@gmail.com", group:"Family"
    assert_includes last_response.body, "Email must be in this format: sample_name@host.domain"
  end

  def test_edit_contact
    # create new
    post '/contacts/new', first_name:"Jane", last_name:"Wayne", phone:"(999)999-9999", phone_type:"Work", email:"sample@gmail.com", group:"Family"

    # edit new
    get '/contacts/2/edit'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Edit Contact"
    post '/contacts/2/edit', first_name:"JaneTwo", last_name:"WayneTwo", phone:"(999)999-9992", phone_type:"Work", email:"sample2@gmail.com", group:"Family"
    assert_equal 302, last_response.status
    assert_equal "Contact JaneTwo WayneTwo was updated!", session[:message]
    get last_response["Location"]
    assert_includes last_response.body, "JaneTwo WayneTwo"

    # delete new
    get '/contacts/2/delete'
  end
end