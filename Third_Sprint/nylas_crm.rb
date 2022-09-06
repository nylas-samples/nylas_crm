# frozen_string_literal: true

# Import dependencies
require 'sinatra'
require 'sinatra/base'
require 'sinatra/config_file'
require 'sqlite3'
require 'nylas'
require 'dotenv/load'
require 'date'

# Call the contacts class
require_relative 'contacts'

# Call the configuration file
config_file 'files/config.yml'

# Define the Nylas class, which will handle the API calls
class Nylas_class
  @@nylas_crm = Nylas::API.new(
    app_id: ENV['CLIENT_ID'],
    app_secret: ENV['CLIENT_SECRET'],
    access_token: ENV['ACCESS_TOKEN']
  )

  def get_account
    @@nylas_crm
  end
end

# Define the DB class, which will read our crm_db.db file
# create the database and tables
class DB
  def initialize
    # If the db exists, open it. Otherwise, create it and open it.
    @@connection = SQLite3::Database.open 'crm_db.db'
    if File.exist?('crm_db.db')
    else
      File.foreach('files/contacts.sql') do |command|
        @@connection.execute(command)
      end
    end
  end

  # Return the connection object
  def get_connection
    @@connection
  end

  # Close the connection object
  def end_connection
    @@connection.close
  end
end

# This is our main page
get '/' do
  # Create a new db connection
  crm_db = DB.new
  # Connect to Nylas
  user_account = Nylas_class.new
  # Get account information
  account = user_account.get_account
  # Call the erb file to generate the HTML
  erb :main, layout: :layout, locals: { account: account.current_account.name }
end
