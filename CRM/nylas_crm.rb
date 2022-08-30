require 'sinatra'
require 'sinatra/base'
require 'sinatra/config_file'
require 'sqlite3'
require 'nylas'
require 'dotenv/load'
require 'httparty'
require 'date'

require_relative 'contacts'
config_file 'files/config.yml'

class Nylas_class	
	@@nylas_crm = Nylas::API.new(
		app_id: ENV["CLIENT_ID"],
		app_secret: ENV["CLIENT_SECRET"],
		access_token: ENV["ACCESS_TOKEN"]
	)
	
	def get_account()
		return @@nylas_crm
	end
end

class DB
	def initialize()
		if(File.exist?('crm_db.db'))
			@@connection = SQLite3::Database.open "crm_db.db"
		else
			@@connection = SQLite3::Database.open "crm_db.db"
			File.foreach("files/contacts.sql") { |command| 
				@@connection.execute(command) 
			}
		end 
	end
	
	def get_connection()
		return @@connection
	end
	
	def end_connection()
		@@connection.close
	end
end

get '/' do
	crm_db = DB.new
	user_account = Nylas_class.new
	account = user_account.get_account()
	erb :main, :layout => :layout, :locals => {:account => account.current_account.name}
end
