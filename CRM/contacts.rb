# Call the parent file
require File.expand_path('../nylas_crm.rb', __FILE__)

# Call the next class file
require_relative 'events'

# Contact class that will handle all contacts related operations
class Contacts < Nylas_class
# When we create an object of this class, we will select contacts
# from our address_book (instead of automatically generated ones)
	def initialize()
		@contacts = @@nylas_crm.contacts.where(source: "address_book")
	end
	
# Return all contacts
	def return_all_contacts()
		return @contacts
	end
	
# Return the contacts create endpoint
	def contacts_create()
		return @@nylas_crm.contacts.create
	end
	
	def file_create()
		return @@nylas_crm.files
	end
	
# Return the contacts object	
	def contact_object()
		return @@nylas_crm.contacts
	end
end

# This will synchronize all contacts into our database
get '/sync_contacts' do
# Create a new contacts object
	contacts_cls = Contacts.new()
# Create a new database object	
	connection = DB.new()
# Open the database	
	conn = connection.get_connection()
# Get all contacts	
	contacts = contacts_cls.return_all_contacts()
# Counter for contacts and for updated contacts	
	total_contacts = 0
	contacts_count = 0
# Loop through each contact	
	contacts.each{|contact|
# How many contacts do we have in total	
		total_contacts = total_contacts + 1
# Select all fields from the merge_mail table by contact id		
		mail = conn.execute( "select * from merge_mail where id = ?", contact.id)
		if mail == []
			conn.execute("insert into merge_mail(id,email,field1,field2,field3,field4,field5) 
				      values (?,?,?,?,?,?,?)",
			              contact.id,contact.emails[0].email,"","","","","")
		end
# Select all fields from the contacts table by contact id
		result = conn.execute( "select * from contacts where id = ?", contact.id)
# If we found results
		if result == []
# Adding a modified contact		
			contacts_count = contacts_count + 1
# Get the contact picture
			picture = contact.picture
# The file name will be first plus last name			
			file_name = contact.given_name + "_" + contact.surname + ".png"
# Create the file if it doesn't exist and download the contact image			
			File.open("public/" + file_name,"wb") do |f|
# Download the contact image			
				f.write File.open(picture, 'rb') {|file| file.read }
			end
			begin
# Format the email by type			
				emails = "type:" +  contact.emails[0].type + ", email:" + contact.emails[0].email
			rescue => error
				emails = ""
			end
			begin
# Build out the address by concatenating different pieces
				address = "city:" + contact.physical_addresses[0].city + 
					", state:" + contact.physical_addresses[0].state +
					", country:" + contact.physical_addresses[0].country +
					", postal_code:" + contact.physical_addresses[0].postal_code + 
					", street_address:" + contact.physical_addresses[0].street_address
			rescue => error
				address = ""
			end
			begin
# Format the phone by type			
				phone = contact.phone_numbers[0].type + ":" + contact.phone_numbers[0].number
			rescue => error
				phone = ""
			end
# Insert the contact details into the database
			conn.execute("insert into contacts(id,given_name,middle_name,nickname,
			               surname,birthday,company_name,notes,
			               picture_url,picture,emails,phone_numbers,
			               physical_address,job_title) values 
			               (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
			               contact.id,contact.given_name,contact.middle_name,
			               contact.nickname,contact.surname,contact.birthday,
			               contact.company_name,contact.notes,contact.picture_url,
			               file_name,emails,phone,address,contact.job_title)
		else
# If the picture field is empty, we need to download the contact image		
			if result[0][9] == ""
# We're updating a contact, so count it			
				contacts_count = contacts_count + 1
# The file name will be first plus last name
				file_name = contact.given_name + "_" + contact.surname + ".png"
# Get the contact picture				
				picture = contact.picture
# Create the file if it doesn't exist and download the contact image				
				File.open("public/" + file_name,"wb") do |f|
# Download the contact image				
					f.write File.open(picture, 'rb') {|file| file.read }
				end
# Update the contacts table				
				conn.execute("update contacts set picture_url=?, picture=?
					      where id=?",contact.picture_url, file_name, contact.id)
				end
		end
	}
# Close the DB connection
	connection.end_connection()
# Call the sync_contacts.erb page	
	erb :sync_contacts, :layout => :layout,:locals => {:total_contacts => total_contacts, :synced => contacts_count}
end

# Show contacts
get '/display_contacts' do
# Create a new DB connection
	connection = DB.new()
# Return the connection object	
	conn = connection.get_connection()
# Get the limit for pagination (how many item to display)	
	limit = params[:limit]
# Select all fields from the contacts table	
	contacts_all = conn.execute( "SELECT * FROM contacts")
# Select all fields from the contact table using limits to help with pagination	
	contacts = conn.execute( "SELECT * FROM contacts WHERE id NOT IN ( SELECT id FROM contacts
				  ORDER BY given_name ASC LIMIT #{limit} ) 
				  ORDER BY given_name ASC LIMIT #{settings.limit}" )
# Add one to the total count of records
	tops = contacts_all.length + 1
# Close the DB connection	
	connection.end_connection()
# Call the display_contacts.erb page	
	erb :display_contacts, :layout => :layout, :locals => {:contacts => contacts, :limit => limit, :tops => tops}
end

# Display parameters to create a new contact. This will be used when updating as well.
get '/create_contact' do
# Create a new DB connection
	connection = DB.new()
# Return the connection object	
	conn = connection.get_connection()
# Select all fields from contacts where the contact id is known	
	result = conn.execute("select * from contacts where id = '#{params[:id]}'")
# Close the DB connection	
	connection.end_connection()
# Specify that we're creating a new contact
	action = "create"
# Call the create_contact.erb page	
	erb :create_contact, :layout => :layout, :locals => {:contact => result, :action => action}
end

# This page will create or update a new contacts
post '/create_update_contact' do
# Create a new contact object
	contacts_cls = Contacts.new()
# Are we creating or updating?
	if params[:action] == "create"
		contact = contacts_cls.contacts_create()	
	else
		contact = contacts_cls.contact_object().find(params[:id])	
	end

# Fill in all parameters
	contact.given_name = params[:given_name]
	contact.middle_name = params[:middle_name]
	contact.nickname = params[:nickname]
	contact.surname = params[:surname]
	contact.birthday = params[:birthday]
	contact.notes = params[:notes]
	contact.company_name = params[:company_name]
	contact.job_title = params[:job_title]
# If there's no email. Don't include	
	if params[:email] != ''
		contact.emails = [{type: params[:email_type], email: params[:email]}]
	end
# If there's no phone. Don't include
	if params[:phone] != ''
		contact.phone_numbers = [{type: params[:phone_type], number: params[:phone]}]
	end
# If there's no street address. Don't include
	if params[:street_address] != '' && params[:street_address] != ' '
		contact.physical_addresses = [{format: 'structured', street_address: params[:street_address], state: params[:state], postal_code: params[:postal_code], city: params[:city], country: params[:country]}]
	end
# Save or update the contact	
	contact.save()
	
# Are we creating a new contact?	
	if params[:action] == "create"
# Create a new DB connection	
		connection = DB.new()
# Return the connection object
		conn = connection.get_connection()
# If the street address parameters is filled, compose the address
		if params[:street_address] != ''
			address = "city:" + params[:city] + 
				", state:" + params[:state] +
				", country:" + params[:country] +
				", postal_code:" + params[:postal_code] + 
				", street_address:" + params[:street_address]
		else
			address = ""
		end
# If the email parameters is filled, compose the email
		if params[:email] != ''
			emails = "type:" +  params[:email_type] + ", email:" + params[:email]
		else
			emails = ""
		end
# If the phone parameters is filled, compose the phone		
		if params[:phone] != ''
			phone = "type:" +  params[:phone_type] + ", phone:" + params[:phone]
		else
			phone = ""
		end
# Clear both picture and file_name parameters		
		picture_url = ""
		file_name = ""
# Create a new record on the contacts table
		result = conn.execute("insert into contacts(id,given_name,middle_name,nickname,
					surname,birthday,company_name,notes,
					picture_url,picture,emails,phone_numbers,
					physical_address,job_title) values 
					(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
					contact.id,params[:given_name],params[:middle_name],
					params[:nickname],params[:surname],params[:birthday],
					params[:company_name],params[:notes],contact.picture_url,
					file_name,emails,phone,address,params[:job_title])	
# Create a new record on the merge_mail table							  
			conn.execute("insert into merge_mail(id,email,field1,field2,field3,field4,field5) 
				      values (?,?,?,?,?,?,?)",contact.id,params[:email],"","","","","")
# Close the connection							  				
		connection.end_connection()
# Call the display_contacts action setting the limit as 0		
		redirect to("/display_contacts?limit=0")
	else
# We're updating a contact
# Create a new DB connection	
	    connection = DB.new()
# Return the connection object
	    conn = connection.get_connection()
# If the street address parameters is filled, compose the address		
	    if params[:street_address] != ""
		    address = "city:" + params[:city] + 
			      ", state:" + params[:state] + 
			      ", country:" + params[:country] +
			      ", postal_code:" + params[:postal_code] + 
			      ", street_address:" + params[:street_address]
	    else
		    address = ""
	    end
# If the email parameters is filled, compose the email		
	    if params[:email] != ""
	        emails = "type:" +  params[:email_type] + ", email:" + params[:email]
	    else
	        emails = ""
	    end
# If the phone parameters is filled, compose the phone		
		if params[:phone] != ""
		    phone = "type:" +  params[:phone_type] + ", phone:" + params[:phone]
		else
		    phone = ""
		end
# Update the record on the contacts table
		conn.execute("update contacts set given_name=?,middle_name=?,nickname=?,
			      surname=?,birthday=?,company_name=?,notes=?,
			      emails=?,phone_numbers=?,physical_address=?,job_title=? 
			      where id=?",
			      params[:given_name],params[:middle_name],
			      params[:nickname],params[:surname],params[:birthday],
			      params[:company_name],params[:notes],emails,
			      phone,address,params[:job_title],params[:id])
# Create the record on the merge_mail table
		mail = conn.execute( "select * from merge_mail where id = ?", params[:id])
		if mail == []
			conn.execute("insert into merge_mail(id,email,field1,field2,field3,field4,field5) 
				      values (?,?,?,?,?,?,?)",
			              contact.id,contact.emails[0].email,"","","","","")
		end							  
# Close the connection
		connection.end_connection()
# Call the display_contacts page setting the limit as 0
		redirect to("/display_contacts?limit=0")	
	end
end

# Delete a contact using the id
get '/delete_contact' do
# Create a new contact object
	contacts_cls = Contacts.new()
# Find the contact by id and delete it	
	contact = contacts_cls.contact_object().find(params[:id]).destroy
# Create a new DB connaction	
	connection = DB.new()
# Return the connection object	
	conn = connection.get_connection()
# Delete from the table contacts using the id	
	conn.execute("delete from contacts where id = '#{params[:id]}'")
# Delete from the table merge_mail using the id
	conn.execute("delete from merge_mail where id = '#{params[:id]}'")
# Close the connection
	connection.end_connection()
# Call the display_contacts page setting the limit as 0	
	redirect to("/display_contacts?limit=0")
end

# Prepare parameters for update
get '/update_contact' do
# Create a new DB connaction	
	connection = DB.new()
# Return the connection object		
	conn = connection.get_connection()
# Select all fields from the contacts table by id	
	result = conn.execute("select * from contacts where id = '#{params[:id]}'")
# Set the action to update	
	action = "update"
# Close the connection
	connection.end_connection()
# Call the create_contact page		
	erb :create_contact, :layout => :layout, :locals => {:contact => result, :action => action}
end
