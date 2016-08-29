require "sinatra"
require "sinatra/reloader"
require "redcarpet"
require "pry"

configure do
  enable :sessions
  set :session_secret, 'super secret'
  set :erb, :escape_html => true
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

get '/' do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index, layout: :layout
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def render_markdown(content)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(content)
end

def error_for_filename(input)
  if input.size == 0
    session[:message] = "A name is required."
  elsif ![".txt", ".md"].any? { |extension| input.include?(extension)}
    session[:mesasge] = "Please include the filename extension (.txt or .md)"
  end
end

def valid_signin?(username, password)
  username == "admin" && password == "secret"
end

get "/new" do
  erb :new
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  if valid_signin?(params[:username], params[:password])
    session[:message] = "Welcome #{params[:username]}"
    session[:username] = params[:username]
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

post "/create" do
  filename = params[:filename].to_s

  error = error_for_filename(filename)
  if error
    session[:message] = error
    status 422
    erb :new
  else
    file_path = File.join(data_path, filename)

    File.write(file_path, "")
    session[:message] = "#{params[:filename]} has been created."

    redirect "/"
  end
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)
  erb :edit, layout: :layout
end

post "/:filename" do
  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])
  session[:message] = "#{params[:filename]} has been updated"
  redirect "/"
end

post "/:filename/delete" do
  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)
  session[:message] = "#{params[:filename]} has been deleted."
  redirect "/"
end
