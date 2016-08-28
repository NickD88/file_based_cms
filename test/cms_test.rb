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

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "unknownfile.bad does not exist."
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

    get "/about.txt/edit"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, "Save Changes</button>"
  end

  def test_saving_edit
    post "/history.txt"
    assert_equal 302, last_response.status
    get last_response["Location"]

    assert_includes last_response.body, "history.txt has been updated"
  end

  def test_create_new_document
    post "/create", filename: "test.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "test.txt has been created"

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_view_add_document_form
    get "/new"
    assert_equal 200, last_response.status

    assert_includes last_response.body, "<input name="
  end

  def test_create_blank_filename
    post "/create", filename: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_filename_without_extension
    post "/create", filename: "text"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Please include the filename extension (.txt or .md)"
  end

  def test_delete_file
    create_document "test_delete.txt"

    post "/test_delete.txt/delete"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "test_delete.txt has been deleted"

    get "/"
    refute_includes last_response.body, "test_delete.txt"
  end
end
