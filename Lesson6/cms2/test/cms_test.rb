ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "fileutils"
require "rack/test"

require_relative "../cms.rb"

Minitest::Reporters.use!

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
    create_document("about.md", "# This is a content management system.")
    create_document("changes.txt", "Nothing has ever changed")
  end

  def create_document(name, content = "")
    File.write("#{data_path}/#{name}", content)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes(last_response.body, "about.md")
  end

  def test_viewing_text_document
    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes(last_response.body, "Nothing has ever changed")
  end

  def test_bad_file_name
    get "/no_such_file.txt"
    assert_equal 302, last_response.status
    get last_response.location
    assert_equal 200, last_response.status
    assert_includes(last_response.body, "'no_such_file.txt' does not exist")
  end

  def test_markdown_rendering
    get "/about.md"
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes(last_response.body, "<h1>This is a content management system.</h1>")
  end

  def test_edit_page
    get "/changes.txt/edit"
    assert_includes(last_response.body, "Nothing has ever changed")
    assert_includes(last_response.body, "<textarea")

    post "/changes.txt", text: "Something has changed!"
    get "/changes.txt"
    assert_includes(last_response.body, "Something has changed!")
  end

  def test_create_doc
    get "/new"
    assert_equal 200, last_response.status
    assert_includes(last_response.body, "<h3>Add a new document:</h3>")

    post "/new", name:"", text:"New content"
    assert_includes(last_response.body, "A name is required")

    post "/new", name:"new_file.ttt", text:"New content"
    assert_includes(last_response.body, "Name of file must end in '.txt' or '.md'")

    post "/new", name:"new_file.txt", text:"New content"
    get last_response.location
    assert_includes(last_response.body, "new_file.txt has been created")

    get "/new_file.txt"
    assert_equal "New content", last_response.body
  end

  def test_delete
    create_document("delete_me.txt", "Please delete me")
    get "/"
    assert_includes(last_response.body, "delete_me.txt")
    
    get "/delete_me.txt/delete"
    get last_response.location
    assert_includes(last_response.body, "delete_me.txt has been deleted")

    get "/"
    refute_includes(last_response.body, "delete_me.txt")
  end
end