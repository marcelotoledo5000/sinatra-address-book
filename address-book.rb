require 'sinatra/base'
require 'slim'
require 'data_mapper'

Slim::Engine.default_options[:pretty] = true

class Address
  include DataMapper::Resource
  property :id,     Serial
  property :name,   String
  property :street, Text
end

class AddressBook < Sinatra::Base
  configure do
    enable :inline_templates
    enable :method_override
  end

  configure :development do
    # This code is run at startup when settings.environment is :development
    DataMapper.setup(:default, "sqlite3://#{settings.root}/development.sqlite3")
    DataMapper.auto_upgrade!
  end

  configure :production do
    # Run in production environment
    DataMapper.setup(:default, ENV['DATABASE_URL'])
    DataMapper.auto_upgrade!
  end

  # Always create a CSRF token
  before do
    session[:csrf] ||= Rack::Protection::Base.new(self).random_string
  end

  ########################################
  # Simple responses and templates

  # The home page - uses a Slim template
  get '/' do
    slim :home
  end

  # Respond with a string
  get '/hello' do
    'Hello!'
  end

  # Pass a parameter to a template
  get '/template_parameter' do
    some_value = 'Got this from the handler'
    slim :template_parameter, locals: {some_value: some_value}
  end

  get '/inline_template' do
    slim :my_inline_template
  end

  ########################################
  # Handlers, routes and parameters

  # A page with a collection of route examples
  get '/route_examples' do
    slim :route_examples
  end

  # Search parameters
  get '/search' do
    slim :show_params, locals: {comment: "You asked for '#{params[:q]}'"}
  end

  # Named parameters - using the 'params' variable
  get '/things/:id' do
    comment = "You asked for thing number '#{params[:id]}'"
    slim :show_params, locals: {comment: comment}
  end

  # Named parameters - using block params
  get '/objects/:id' do |id|
    comment = "You asked for object number '#{id}'"
    slim :show_params, locals: {comment: comment}
  end

  # Splats
  get '/the/*/of/*' do
    comment = "You asked for 'the #{params[:splat][0]} of #{params[:splat][1]}'"
    slim :show_params, locals: {comment: comment}
  end

  # Optional parameters - format defaults to 'html'
  get '/conditions.?:format?' do |format = 'html'|
    comment = "format: #{format}"
    slim :show_params, locals: {comment: comment}
  end

  # Regular expressions in routes
  get %r{/words/([a-z]+)} do
    comment = "word: #{params[:captures][0]}"
    slim :show_params, locals: {comment: comment}
  end

  ########################################
  # POST: Protecting from CSRF attacks

  # A form with CSRF protection
  get '/username' do
    slim :username, locals: {username: 'myuser'}
  end

  # Receive a POST - this gets through if the CSRF token is correct
  post '/username' do
    "Your new username is '#{params[:username]}'"
  end

  ########################################
  # POST: Uploading files

  # A form for file upload
  get '/photos' do
    slim :photo_upload
  end

  # Save an uploaded file
  # Note - this doesn't work on Heroku
  post '/photos' do
    if params[:photo].nil?
      redirect '/photos'
      return
    end
    filename = File.join(settings.root, 'files', params[:photo][:filename])
    File.open(filename, 'w') do |file|
      file.write params[:photo][:tempfile].read
    end
    "OK, photo saved"
  end

  ########################################
  # Route conditions

  # provides

  # Specify that we want a JSON response
  # use curl to test this:
  #   curl -H 'Accept: application/json' http://0.0.0.0:3000/provides
  get '/provides', provides: :json do
    '{result: "You asked for JSON"}'
  end

  # Don't specify the response type
  #   curl http://0.0.0.0:3000/provides
  get '/provides' do
    'This is the default handler'
  end

  ########################################
  # The addresses application

  get '/addresses' do
    addresses = Address.all
    slim :'addresses/index', locals: {addresses: addresses}
  end

  post '/addresses' do
    address = Address.new(params[:address])

    if address.save
      redirect '/addresses'
    else
      redirect '/addresses/new'
    end
  end

  get '/addresses/new' do
    address = Address.new
    slim :'addresses/new', locals: {address: address}
  end

  delete '/addresses/:id' do |id|
    address = Address.get!(id)
    address.destroy!
    redirect '/addresses'
  end
end

__END__

@@my_inline_template
h1 This is an inline template

@@show_params
p = comment
p
  | params:
  = params.inspect
p
  a href="/route_examples" Back

