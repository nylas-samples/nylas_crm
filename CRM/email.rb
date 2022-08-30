require File.expand_path('../nylas_crm.rb', __FILE__)

class Emails < Nylas_class
	def initialize()
		@emails = @@nylas_crm.messages
	end
	
	def return_emails
		return @emails
	end
	
	def return_send
		return @@nylas_crm
	end
	
	def return_labels
		return @@nylas_crm.labels
	end
end

get '/mail_merge_fields' do
	connection = DB.new()
	conn = connection.get_connection()
	result = conn.execute( "select * from merge_fields")
	connection.end_connection()
	erb :mail_merge_fields, :layout => :layout, :locals => {:mail_merge_fields => result}	
end

post '/mail_merge_fields' do
	connection = DB.new()
	conn = connection.get_connection()
	conn.execute( "delete from merge_fields")
	conn.execute("insert into merge_fields(field1,description1,field2,description2,
			              field3,description3,field4,description4,field5,description5) values 
			              (?,?,?,?,?,?,?,?,?,?)",
			              params[:field_one],params[:field_one_desc],
			              params[:field_two],params[:field_two_desc],
			              params[:field_three],params[:field_three_desc],
			              params[:field_four],params[:field_four_desc],
			              params[:field_five],params[:field_five_desc])
	connection.end_connection()
	redirect to("/")
end

get '/send_email' do
	connection = DB.new()
	conn = connection.get_connection()
	contacts = conn.execute( "select * from contacts")
	connection.end_connection()
	erb :send_email, :layout => :layout, :locals => {:contacts => contacts}	
end

get '/reply_email' do
	emails_cls = Emails.new()
	emails_obj = emails_cls.return_emails()
	email = emails_obj.find(params[:email])
	erb :reply_email, :layout => :layout, :locals => {:email => email}
end

get '/delete_email' do
	emails_cls = Emails.new()
	labelsDict = Hash.new
	labels = emails_cls.return_labels()
	labels.each{ |label|
		labelsDict[label.name] = label.id
	}
	emails_obj = emails_cls.return_emails()
	email = emails_obj.find(params[:email])
	email.update(label_ids: [labelsDict["trash"]])
	email.save
	redirect to("/get_emails")
end

post '/send_email' do
	emails_cls = Emails.new()
	emails_obj = emails_cls.return_send()
	participants_list = params[:participants_list].split(/\;/)
	names_list = params[:names_list].split(/\;/)
	participants = []
	i = 0
	participants_list.each{ |participant|
		participants.push({name: "#{names_list[i]}", email: "#{participant}"})
		i = i + 1 
	}	
	body = params[:body].gsub(/<div>/,"").gsub(/<\/div>/,"")
	
	if(params[:reply_to] == nil)
		emails_obj.send!(to: participants, subject: params[:subject], body: body).to_h
	else
		emails_obj.send!(to: participants, subject: params[:subject], reply_to: params[:reply_to], body: body).to_h
	end
	
	redirect to("/get_emails")
end

get '/mail_merge_contacts' do
	connection = DB.new()
	conn = connection.get_connection()
	contacts = conn.execute( "select * from contacts")
	merge = conn.execute( "select * from merge_mail")
	fields = conn.execute("select * from merge_fields")
	connection.end_connection()
	erb :mail_merge_contacts, :layout => :layout, :locals => {:contacts => contacts, :merge => merge, :fields => fields}	
end

post '/mail_merge_contacts' do
	connection = DB.new()
	conn = connection.get_connection()
	conn.execute("update merge_mail set field1=?, field2=?, field3=?,field4=?,field5=?
						  where id=?",
						  params[:field1_name] + ":" + params[:field1],
						  params[:field2_name] + ":" + params[:field2],
						  params[:field3_name] + ":" + params[:field3],
						  params[:field4_name] + ":" + params[:field4],
						  params[:field5_name] + ":" + params[:field5],
						  params[:id])
	connection.end_connection()
	redirect to("/mail_merge_contacts")						  
end

get '/display_emails' do
	emails_cls = Emails.new()
	emails_obj = emails_cls.return_emails()
	connection = DB.new()
	conn = connection.get_connection()	
	if(params[:email_limit] == nil)
		emails = emails_obj.where(in: "inbox").limit(settings.fetch_emails)
		conn.execute( "delete from emails")
		emails.each{ |email|
			puts email
			conn.execute("insert into emails(id,date,subject,name,email,unread) 
								 values (?,?,?,?,?,?)",
			              email.id,email.date.to_s,email.subject,
			              email.from.first.name,
			              email.from.first.email,email.unread.to_s)			
		}
		email_limit = 0
		emails_all = conn.execute( "SELECT * FROM emails")
		emails = conn.execute( "SELECT * FROM emails WHERE id NOT IN ( SELECT id FROM emails
											ORDER BY date DESC LIMIT #{email_limit} ) ORDER BY date DESC LIMIT #{settings.email_limit}" )
		tops = emails_all.length + 1
		connection.end_connection()
	else
		email_limit = params[:email_limit]
		emails_all = conn.execute( "SELECT * FROM emails")
		emails = conn.execute( "SELECT * FROM emails WHERE id NOT IN ( SELECT id FROM emails
											ORDER BY date DESC LIMIT #{email_limit} ) ORDER BY date DESC LIMIT #{settings.email_limit}" )
		tops = emails_all.length + 1
		connection.end_connection()	
	end
	erb :display_emails, :layout => :layout, :locals => {:emails => emails, :email_limit => email_limit, :tops => tops}
end

get '/read_email' do
	emails_cls = Emails.new()
	emails_obj = emails_cls.return_emails()
	email = emails_obj.find(params[:email])
	email.update(unread: false)
	erb :read_email, :layout => :layout, :locals => {:email => email}
end

get '/send_mail_merge' do
	connection = DB.new()
	conn = connection.get_connection()
	contacts = conn.execute( "select * from contacts")
	merge = conn.execute( "select * from merge_fields")
	connection.end_connection()
	erb :send_mail_merge, :layout => :layout, :locals => {:contacts => contacts, :merge => merge}
end

post '/send_mail_merge' do
	emails_cls = Emails.new()
	emails_obj = emails_cls.return_send()
	connection = DB.new()
	conn = connection.get_connection()	
	participants_list = params[:participants_list].split(/\;/)
	names_list = params[:names_list].split(/\;/)
	ids_list = params[:ids_list].split(/\;/)
	i = 0
	merge_fields = conn.execute("select field1, field2, field3, field4, field5 from merge_fields")
	participants_list.each{ |participant|
		participants = []
		participants.push({name: "#{names_list[i]}", email: "#{participant}"})
		contacts = conn.execute( "select given_name, nickname, surname, birthday, physical_address from contacts where id = ?", ids_list[i])
		merge_mail = conn.execute("select field1, field2, field3, field4, field5 from merge_mail where id = ?", ids_list[i])
		subject = params[:subject]
		body = params[:body].gsub(/<div>/,"").gsub(/<\/div>/,"")
		begin
			subject = subject.gsub(/{given_name}/,contacts[0][0])
			body = body.gsub(/{given_name}/,contacts[0][0])
		rescue => error
			subject = subject.gsub(/{given_name}/,"<Given Name not found, please update>")
			body = body.gsub(/{given_name}/,"<Given Name not found, please update>")
		end
		begin
			subject = subject.gsub(/{nickname}/,contacts[0][1])
			body = body.gsub(/{nickname}/,contacts[0][1])
		rescue => error
			subject = subject.gsub(/{nickname}/,"<Nickname not found, please update>")
			body = body.gsub(/{nickname}/,"<Nickname not found, please update>")
		end
		begin
			subject = subject.gsub(/{surname}/,contacts[0][2])
			body = body.gsub(/{surname}/,contacts[0][2])
		rescue => error
			subject = subject.gsub(/{surname}/,"<Surname not found, please update>")
			body = body.gsub(/{surname}/,"<Surname not found, please update>")
		end
		begin 
			subject = subject.gsub(/{birthday}/,contacts[0][3])
			body = body.gsub(/{birthday}/,contacts[0][3])
		rescue => error
			subject = subject.gsub(/{birthday}/,"<Birthday not found, please update>")
			body = body.gsub(/{birthday}/,"<Birthday not found, please update>")
		end
		begin 
			physical_address = contacts[0][4]
			street = physical_address.scan(/(?<=street_address:).+/) 
			country = physical_address.scan(/(?<=country:)(.*?,)/) 
			city = physical_address.scan(/(?<=city:)(.*?,)/) 
			postal = physical_address.scan(/(?<=postal_code:)(.*?,)/) 
			state = physical_address.scan(/(?<=state:)(.*?,)/)
					     begin
							city = city[0][0].gsub(/,/,"") 
					     rescue => error
							city[0] = ""
					     end
					     begin
							country = country[0][0].gsub(/,/,"") 
					     rescue => error
							country[0] = ""
					     end
					     begin
							postal = postal[0][0].gsub(/,/,"") 
					     rescue => error
							postal[0] = ""
					     end
					     begin
							state = state[0][0].gsub(/,/,"") 
					     rescue => error
							state[0] = ""
					     end
					     if street[0].to_s != ''
							address = street[0].to_s + ", " + city.to_s + ", " + state.to_s + ", " + country.to_s + ", " + postal.to_s
					     else
							address = "<Address not found. Please update>"
					     end				
			subject = subject.gsub(/{physical_address}/,address)
			body = body.gsub(/{physical_address}/,address)
		rescue => error
		end
		
		field1 = merge_mail[0][0].to_s.split(":")
		field1 = field1[1]
		field2 = merge_mail[0][1].to_s.split(":")
		field2 = field2[1]
		field3 = merge_mail[0][2].to_s.split(":")
		field3 = field3[1]
		field4 = merge_mail[0][3].to_s.split(":")
		field4 = field4[1]
		field5 = merge_mail[0][4].to_s.split(":")
		field5 = field5[1]
		
		begin
			subject = subject.gsub(/{#{merge_fields[0][0]}}/,field1)
			body = body.gsub(/{#{merge_fields[0][0]}}/,field1)
		rescue => error
			subject = subject.gsub(/{#{merge_fields[0][0]}}/,"<#{merge_fields[0][0]} not found. Please update>")
			body = body.gsub(/{#{merge_fields[0][0]}}/,"<#{merge_fields[0][0]} not found. Please update>")
		end
		begin
			subject = subject.gsub(/{#{merge_fields[0][1]}}/,field2)
			body = body.gsub(/{#{merge_fields[0][1]}}/,field2)
		rescue => error
			subject = subject.gsub(/{#{merge_fields[0][1]}}/,"<#{merge_fields[0][1]} not found. Please update>")
			body = body.gsub(/{#{merge_fields[0][1]}}/,"<#{merge_fields[0][1]} not found. Please update>")
		end
		begin
			subject = subject.gsub(/{#{merge_fields[0][2]}}/,field3)
			body = body.gsub(/{#{merge_fields[0][2]}}/,field3)
		rescue => error
			subject = subject.gsub(/{#{merge_fields[0][2]}}/,"<#{merge_fields[0][2]} not found. Please update>")
			body = body.gsub(/{#{merge_fields[0][2]}}/,"<#{merge_fields[0][2]} not found. Please update>")
		end
		begin
			subject = subject.gsub(/{#{merge_fields[0][3]}}/,field4)
			body = body.gsub(/{#{merge_fields[0][3]}}/,field4)
		rescue => error
			subject = subject.gsub(/{#{merge_fields[0][3]}}/,"<#{merge_fields[0][3]} not found. Please update>")
			body = body.gsub(/{#{merge_fields[0][3]}}/,"<#{merge_fields[0][3]} not found. Please update>")
		end
		begin
			subject = subject.gsub(/{#{merge_fields[0][4]}}/,field5)
			body = body.gsub(/{#{merge_fields[0][4]}}/,field5)
		rescue => error
			subject = subject.gsub(/{#{merge_fields[0][4]}}/,"<#{merge_fields[0][4]} not found. Please update>")
			body = body.gsub(/{#{merge_fields[0][4]}}/,"<#{merge_fields[0][4]} not found. Please update>")
		end
		
		i = i + 1 
		
		emails_obj.send!(to: participants, subject: subject, body: body).to_h
	}
		
	redirect to("/get_emails")	
end
