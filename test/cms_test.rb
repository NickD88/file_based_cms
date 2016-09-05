ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms.rb"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def test_index
    create_document "about.txt"
    create_document "changes.md"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.txt"
    assert_includes last_response.body, "changes.md"
  end

  def test_file
    create_document "about.txt", "about file!"

    get "/about.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "about file!"
  end

  def test_file_exists
    get "/unknownfile.bad"

    assert_equal 302, last_response.status
    assert_equal "unknownfile.bad does not exist.", session[:message]
  end

  def test_markdown_rendering
    create_document "changes.md", "# This is a markdown File"

    get "/changes.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>This is a markdown File</h1>"
  end

  def test_editing_files
    create_document "about.txt"

    get "/about.txt/edit", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, "Save Changes</button>"
  end

  def test_saving_edit
    post "/history.txt", {content: "new content"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "history.txt has been updated", session[:message]

    get "/history.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_create_new_document
    post "/create", {filename: "test.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt has been created.", session[:message]

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_view_add_document_form
    get "/new", {}, admin_session
    assert_equal 200, last_response.status

    assert_includes last_response.body, "<input name="
  end

  def test_create_blank_filename
    post "/create", { filename: "" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_filename_without_extension
    post "/create", { filename: "text" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Please include the filename extension (.txt or .md)"
  end

  def test_delete_file
    create_document "test_delete.txt"

    post "/test_delete.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test_delete.txt has been deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome admin!", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid credentials"
    assert_equal nil, session[:username]
  end

  def test_signout
    get "/", {}, {"rack.session" => { username: "admin" } }
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    get last_response["Location"]

    assert_equal nil, session[:username]
    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, "Sign In"
  end

  def editing_document_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_includes "You must be signed in to do that", last_response.status
  end
end
