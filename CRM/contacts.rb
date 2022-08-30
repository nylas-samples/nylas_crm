require File.expand_path('../nylas_crm.rb', __FILE__)

require_relative 'events'

class Contacts < Nylas_class
	def initialize()
		@contacts =	 @@nylas_crm.contacts.where(source: "address_book")
	end
	
	def return_all_contacts()
		return @contacts
	end
	
	def contacts_create()
		return @@nylas_crm.contacts.create
	end
	
	def file_create()
		return @@nylas_crm.files
	end
	
	def contact_object()
		return @@nylas_crm.contacts
	end
end

get '/sync_contacts' do
	contacts_cls = Contacts.new()
	connection = DB.new()
	conn = connection.get_connection()
	contacts = contacts_cls.return_all_contacts()
	total_contacts = 0
	contacts_count = 0
	contacts.each{|contact|
		total_contacts = total_contacts + 1
		mail = conn.execute( "select * from merge_mail where id = ?", contact.id)
		if mail == []
			conn.execute("insert into merge_mail(id,email,field1,field2,field3,field4,field5) 
								  values (?,?,?,?,?,?,?)",
			                    contact.id,contact.emails[0].email,"","","","","")
		end
		
		result = conn.execute( "select * from contacts where id = ?", contact.id)
		if result == []
			contacts_count = contacts_count + 1
			picture = contact.picture
			file_name = contact.given_name + "_" + contact.surname + ".png"
			File.open("public/" + file_name,"wb") do |f|
				f.write File.open(picture, 'rb') {|file| file.read }
			end
			begin
				emails = "type:" +  contact.emails[0].type + ", email:" + contact.emails[0].email
			rescue => error
				emails = ""
			end
			begin
				address = "city:" + contact.physical_addresses[0].city + 
								", state:" + contact.physical_addresses[0].state +
								", country:" + contact.physical_addresses[0].country +
								", postal_code:" + contact.physical_addresses[0].postal_code + 
								", street_address:" + contact.physical_addresses[0].street_address
			rescue => error
				address = ""
			end
			begin
				phone = contact.phone_numbers[0].type + ":" + contact.phone_numbers[0].number
			rescue => error
				phone = ""
			end
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
			if result[0][9] == ""
				contacts_count = contacts_count + 1
				file_name = contact.given_name + "_" + contact.surname + ".png"
				picture = contact.picture
				File.open("public/" + file_name,"wb") do |f|
					f.write File.open(picture, 'rb') {|file| file.read }
				end
				conn.execute("update contacts set picture_url=?, picture=?
							where id=?",
							contact.picture_url, file_name, contact.id)
				end
		end
	}
	connection.end_connection()
	erb :sync_contacts, :layout => :layout,:locals => {:total_contacts => total_contacts, :synced => contacts_count}
end

get '/display_contacts' do
	connection = DB.new()
	conn = connection.get_connection()
	limit = params[:limit]
	contacts_all = conn.execute( "SELECT * FROM contacts")
	contacts = conn.execute( "SELECT * FROM contacts WHERE id NOT IN ( SELECT id FROM contacts
											ORDER BY given_name ASC LIMIT #{limit} ) ORDER BY given_name ASC LIMIT #{settings.limit}" )
	tops = contacts_all.length + 1
	connection.end_connection()
	erb :display_contacts, :layout => :layout, :locals => {:contacts => contacts, :limit => limit, :tops => tops}
end

get '/create_contact' do
	connection = DB.new()
	conn = connection.get_connection()
	result = conn.execute("select * from contacts where id = '#{params[:id]}'")
	connection.end_connection()
	action = "create"
	erb :create_contact, :layout => :layout, :locals => {:contact => result, :action => action}
end

post '/create_update_contact' do
	contacts_cls = Contacts.new()
	if params[:action] == "create"
		contact = contacts_cls.contacts_create()	
	else
		contact = contacts_cls.contact_object().find(params[:id])	
	end

	contact.given_name = params[:given_name]
	contact.middle_name = params[:middle_name]
	contact.nickname = params[:nickname]
	contact.surname = params[:surname]
	contact.birthday = params[:birthday]
	contact.notes = params[:notes]
	contact.company_name = params[:company_name]
	contact.job_title = params[:job_title]
	if params[:email] != ''
		contact.emails = [{type: params[:email_type], email: params[:email]}]
	end
	if params[:phone] != ''
		contact.phone_numbers = [{type: params[:phone_type], number: params[:phone]}]
	end
	if params[:street_address] != '' && params[:street_address] != ' '
		contact.physical_addresses = [{format: 'structured', street_address: params[:street_address], state: params[:state], postal_code: params[:postal_code], city: params[:city], country: params[:country]}]
	end
	contact.save()
	
	if params[:action] == "create"
		connection = DB.new()
		conn = connection.get_connection()
		if params[:street_address] != ''
			address = "city:" + params[:city] + 
							", state:" + params[:state] +
							", country:" + params[:country] +
							", postal_code:" + params[:postal_code] + 
							", street_address:" + params[:street_address]
		else
			address = ""
		end
		if params[:email] != ''
			emails = "type:" +  params[:email_type] + ", email:" + params[:email]
		else
			emails = ""
		end
		if params[:phone] != ''
			phone = "type:" +  params[:phone_type] + ", phone:" + params[:phone]
		else
			phone = ""
		end
		picture_url = ""
		file_name = ""
		result = conn.execute("insert into contacts(id,given_name,middle_name,nickname,
							  surname,birthday,company_name,notes,
							  picture_url,picture,emails,phone_numbers,
							  physical_address,job_title) values 
							  (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
							  contact.id,params[:given_name],params[:middle_name],
							  params[:nickname],params[:surname],params[:birthday],
							  params[:company_name],params[:notes],contact.picture_url,
							  file_name,emails,phone,address,params[:job_title])	
							  
			conn.execute("insert into merge_mail(id,email,field1,field2,field3,field4,field5) 
								  values (?,?,?,?,?,?,?)",
			                    contact.id,params[:email],"","","","","")
							  				
		connection.end_connection()
		redirect to("/display_contacts?limit=0")
	else
		connection = DB.new()
		conn = connection.get_connection()
		if params[:street_address] != ""
			address = "city:" + params[:city] + 
							", state:" + params[:state] + 
							", country:" + params[:country] +
							", postal_code:" + params[:postal_code] + 
							", street_address:" + params[:street_address]
		else
			address = ""
		end
		if params[:email] != ""
			emails = "type:" +  params[:email_type] + ", email:" + params[:email]
		else
			emails = ""
		end
		if params[:phone] != ""
			phone = "type:" +  params[:phone_type] + ", phone:" + params[:phone]
		else
			phone = ""
		end
		
		conn.execute("update contacts set given_name=?,middle_name=?,nickname=?,
							  surname=?,birthday=?,company_name=?,notes=?,
							  emails=?,phone_numbers=?,physical_address=?,job_title=? 
							  where id=?",
							  params[:given_name],params[:middle_name],
							  params[:nickname],params[:surname],params[:birthday],
							  params[:company_name],params[:notes],emails,
							  phone,address,params[:job_title],params[:id])

		mail = conn.execute( "select * from merge_mail where id = ?", params[:id])
		if mail == []
			conn.execute("insert into merge_mail(id,email,field1,field2,field3,field4,field5) 
								  values (?,?,?,?,?,?,?)",
			                    contact.id,contact.emails[0].email,"","","","","")
		end							  
							  
		connection.end_connection()
		redirect to("/display_contacts?limit=0")	
	end
	
    #filename = params[:given_name] + "_" + params[:surname] + File.extname(params[:file][:filename])
    #file = params[:file][:tempfile]
	
    #File.open(File.join(settings.public_folder, filename), 'wb') do |f|
		#f.write file.read
    #end	
	
	#file_obj = contacts_cls.file_create()
	#file = file_obj.create(file: File.open(File.expand_path(File.join(settings.public_folder, filename)), 'r')).to_h

	#@body = {
		#"picture_url" => "https://pbs.twimg.com/profile_images/1483394037902188545/I9vZIYxX_400x400.jpg"
	#}	
	#HTTParty.put('https://api.nylas.com/contacts/' + contact.id, 
		                  #:headers => headers,
		                  #:body => @body.to_json)		
end

get '/delete_contact' do
	contacts_cls = Contacts.new()
	contact = contacts_cls.contact_object().find(params[:id]).destroy
	connection = DB.new()
	conn = connection.get_connection()
	conn.execute("delete from contacts where id = '#{params[:id]}'")
	conn.execute("delete from merge_mail where id = '#{params[:id]}'")
	connection.end_connection()
	redirect to("/display_contacts?limit=0")
end

get '/update_contact' do
	connection = DB.new()
	conn = connection.get_connection()
	result = conn.execute("select * from contacts where id = '#{params[:id]}'")
	action = "update"
	connection.end_connection()
	erb :create_contact, :layout => :layout, :locals => {:contact => result, :action => action}
end
