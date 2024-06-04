ENV["RACK_ENV"] = "test"

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative "../cms.rb"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { signed_in: true } }
  end

  def setup
    FileUtils.mkdir_p(data_path)
    get '/', {}, admin_session
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, contents="")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(contents)
    end
  end

  def test_home
    create_document("history.txt", "This is some history")
    create_document("about.md", "#This is the headline")
    get '/'
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "history.txt"
    assert_includes last_response.body, "about.md"
  end

  def test_history_file
    create_document("history.txt", "This is some history")

    get '/history.txt'
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "This is some history"
  end

  def test_bad_request
    get '/no_such.txt'
    assert_equal 302, last_response.status
    assert_equal "no_such.txt does not exist.", session[:message]
    get last_response["Location"]
    get "/"
    refute_equal "no_such.txt does not exist.", session[:message]
  end

  def test_render_markdown
    create_document("about.md", "#This is the headline")

    get '/about.md'
    assert_equal 200, last_response.status
    assert_equal "text/html", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>This is the headline</h1>"
  end

  def test_file_editing
    create_document("changes.txt", "old content")
    
    get '/changes.txt/edit'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "changes"
    
    post "/changes.txt", contents:"new content"
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]
    get last_response["Location"]

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_new_file
    get '/new'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Name of new .md or .txt document:"

    post '/new', file_name:""
    assert_includes last_response.body, "File must have non-empty name"

    post '/new', file_name:"asdf..txt"
    assert_includes last_response.body, "Name cannot include a period (except for the extension)"
  
    post '/new', file_name:"new.bad_extension"
    assert_includes last_response.body, "File name must have .#{FILETYPES.join(' or .')} extension"

    post '/new', file_name:"test.txt"
    assert_equal 302, last_response.status
    assert_equal "test.txt has been successfully created", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "test.txt</a>"

    get '/test.txt'
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal last_response.body, ""

    get '/new'
    post '/new', file_name:"test.md"
    assert_equal 302, last_response.status
    assert_equal "test.md has been successfully created", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "test.md</a>"

    get '/test.md'
    assert_equal 200, last_response.status
    assert_equal "text/html", last_response["Content-Type"]
  end

  def test_delete
    create_document("history.txt", "This is some history")

    get '/'
    assert_includes last_response.body, "history.txt"
    post '/history.txt/delete'
    assert_equal 302, last_response.status
    assert_equal "history.txt has been deleted", session[:message]

    get last_response["Location"]
    get '/'
    refute_includes last_response.body, "history.txt"
  end

  def test_signin_success
    get '/', {}, admin_session
    assert session[:signed_in]

    post '/users/signout'
    assert_equal "You have been signed out", session[:message]
    refute session[:signed_in]

    # redirects to index
    get last_response["Location"]

    # signin
    post '/users/signin', username:"admin", password:"secret"
    assert_equal "Welcome!", session[:message]
    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin."
    assert_includes last_response.body, "Sign out"
  end

  def test_signin_bad_credentials
    post '/users/signout'

    # redirects to index
    assert_equal 302, last_response.status
    get last_response["Location"]

    # bad credentials
    post '/users/signin', username:"badmin", password:"secret"
    assert_includes last_response.body, "Invalid credentials"
    assert_equal 422, last_response.status

    post '/users/signin', username:"badmin", password:"secret3"
    assert_includes last_response.body, "Invalid credentials"
    assert_equal 422, last_response.status
  end

  def test_not_signed_in
    create_document("history.txt", "This is some history")

    # signout
    post '/users/signout'
    assert_equal "You have been signed out", session[:message]
    refute session[:signed_in]

    # clear message
    get '/'

    # try to edit
    get '/history.txt/edit'
    assert_equal "You must be signed in to edit a file.", session[:message]
    post '/history.txt'
    assert_equal 302, last_response.status

    # try to delete
    post '/history.txt/delete'
    assert_equal "You must be signed in to delete a file", session[:message]

    # try to create new
    get '/new'
    assert_equal "You must be signed in to create a file.", session[:message]
    post '/new', file_name:"test.txt"
    assert_equal 302, last_response.status
  end

  def test_admin_edit_users
    # get to user page
    get '/useraccts'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Select username to delete"

    # add user
    post '/useraccts', username:'guest2', password:'..'
    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, "guest2"
    get '/'

    # try to signin as new user
    post '/users/signout'
    get '/users/signin'
    post '/users/signin', username:'guest2', password:'..'
    get last_response["Location"]
    assert_includes last_response.body, "Signed in as guest2"

    # switch to admin account
    post '/users/signout'
    get '/users/signin'
    post '/users/signin', username:'admin', password:'secret'
    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"

    # try to delete user
    get '/useraccts'
    post '/users/delete', name:'guest2'
    get last_response["Location"]
    assert_includes last_response.body, "Successfully deleted guest2"
  end

  def test_duplicate
    create_document("changes.txt", "old content")

    get '/changes.txt/edit'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "changes"
    
    post "/duplicate", duplicate: "changes.txt"
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been duplicated", session[:message]
    get last_response["Location"]

    assert_includes last_response.body, "changes_copy.txt"

  end

  def test_rename
    create_document("changes.txt", "old content")

    get '/changes.txt/rename'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "changes.txt"

    post '/changes.txt/rename', new_name:"changes2.txt"
    assert_equal "changes2.txt has been successfully renamed", session[:message]
    assert_equal 302, last_response.status
    get last_response["Location"]

    assert_includes last_response.body, "changes2.txt"
  end

  def test_bad_rename
    create_document("changes.txt", "old content")

    post '/changes.txt/rename', new_name: ""
    assert_includes last_response.body, "File must have non-empty name"

    post '/changes.txt/rename', new_name: "asdf..txt"
    assert_includes last_response.body, "Name cannot include a period (except for the extension)"
  
    post '/changes.txt/rename', new_name: "new.bad_extension"
    assert_includes last_response.body, "File name must have .#{FILETYPES.join(' or .')} extension"
  end

  def test_bad_input_create_acct
    get '/users/new_acct'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "New User Account Information"

    post '/users/new_acct', username: "", password: ""
    assert_includes last_response.body, "Neither field can be left blank."

    post '/users/new_acct', username: "x", password: ""
    assert_includes last_response.body, "Neither field can be left blank."

    post '/users/new_acct', username: "", password: "x"
    assert_includes last_response.body, "Neither field can be left blank."

    post '/users/new_acct', username: "admin", password: "x"
    assert_includes last_response.body, "Username already in use."
  end

  def test_create_acct
    # delete account to be created, in case already exists
    get '/useraccts'
    post '/users/delete', name:'guest3'

    post '/users/new_acct', username: "guest3", password: "fff"
    assert_equal "New account successfully created. Please sign in.", session[:message]
    get last_response["Location"]
    post '/users/signin', username:"guest3", password:"fff"
    assert_equal "Welcome!", session[:message]
    get last_response["Location"]
    assert_includes last_response.body, "Signed in as guest3."
  end
end