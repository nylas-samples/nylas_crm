require File.expand_path('../nylas_crm.rb', __FILE__)

require_relative 'email'

class Events < Nylas_class
	def initialize()
		@calendar =	@@nylas_crm.calendars
		@events = @@nylas_crm.events.where(calendar_id: ENV["CRM_CALENDAR_ID"])
	end
	
	def create_calendar
		return @calendar
	end
	
	def return_events
		return @events
	end
	
	def events_create()
		return @@nylas_crm.events
	end
	
	def event_object()
		return @@nylas_crm.events
	end	
end

get '/create_calendar' do
	if ENV["CRM_CALENDAR_ID"] == nil
		calendar_cls = Events.new()
		calendar_obj = calendar_cls.create_calendar()
		calendar = calendar_obj.create(
							name: "#{settings.calendar_name}",
							description: "#{settings.calendar_description}",
						)
		File.open(".env", "a") { |f| f.write "export CRM_CALENDAR_ID=#{calendar.id}" }
		erb :calendar_created, :layout => :layout,:locals => {:message => "The #{settings.calendar_name} has been created."}
	else
		erb :calendar_created, :layout => :layout,:locals => {:message => "The #{settings.calendar_name} already exists."}
	end
end

get '/create_event' do
	connection = DB.new()
	conn = connection.get_connection()
	contacts = conn.execute( "select * from contacts")
	event = conn.execute("select * from events where id = '#{params[:id]}'")
	connection.end_connection()
	action = "create"
	erb :create_event, :layout => :layout, :locals => {:contacts => contacts, :event => event, :action => action}
end

post '/create_update_event' do
	calendar_cls = Events.new()
	connection = DB.new()
	conn = connection.get_connection()

	startDate = params[:start_date].split(/\-/)
	startTime = params[:start_time].split(/\:/)
	endDate = params[:end_date].split(/\-/)
	endTime = params[:end_time].split(/\:/)
	participants_list = params[:participants_list].split(/\;/)
	names_list = params[:names_list].split(/\;/)
	phones_list = params[:phones_list].split(/\;/)
	participants = []
	participant_emails = ""
	participant_names = ""
	participant_phones = ""
	
	i = 0
	participants_list.each{ |participant|
		participants.push({name: "#{names_list[i]}", email: "#{participant}"})
		participant_emails = participant_emails + participant + "/"
		participant_names = participant_names + names_list[i] + "/"
		participant_phones = participant_phones + phones_list[i].to_s + "/"
		i = i + 1 
	}
	
	participant_emails = participant_emails.chomp("/")
	participant_names = participant_names.chomp("/")
	participant_phones = participant_phones.gsub(/\s/,'')
	participant_phones = participant_phones.gsub("\/","")
	
	email_notification_title = params[:title] + " starts in " + params[:email_before] + " minutes"

	if params[:action] == "create"
		calendar_obj = calendar_cls.events_create()
		if params[:email_notification] == "email_notification"
			event = calendar_obj.create(title: params[:title], description: params[:description], location: params[:location],
													when:{start_time: Time.local(startDate[0],startDate[1],startDate[2],startTime[0],startTime[1],0).strftime("%s"),
													end_time: Time.local(endDate[0],endDate[1],endDate[2],endTime[0],endTime[1],0).strftime("%s")},
													participants: participants,calendar_id: ENV["CRM_CALENDAR_ID"], 
													notify_participants: true,notifications: [{type: "email", minutes_before_event: "#{params[:email_before]}",subject: email_notification_title,
													body: email_notification_title}])	
		else
			event = calendar_obj.create(title: params[:title], description: params[:description], location: params[:location],
													when:{start_time: Time.local(startDate[0],startDate[1],startDate[2],startTime[0],startTime[1],0).strftime("%s"),
													end_time: Time.local(endDate[0],endDate[1],endDate[2],endTime[0],endTime[1],0).strftime("%s")},
													participants: participants,calendar_id: ENV["CRM_CALENDAR_ID"], 
													notify_participants: true)	
		end
		
		conn.execute("insert into events(id,title,description,location,start_date,
							  start_time,end_date,end_time,participants_list,
							  names_list,phones_list,email_remind,email_minutes) values 
							  (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
							  event.id,params[:title],params[:description],
							  params[:location],params[:start_date],params[:start_time],
							  params[:end_date],params[:end_time],participant_emails,
							  participant_names,participant_phones,params[:email_notification], 
							  params[:email_before])
	else
		event = events_cls.event_object().find(params[:id])
		if params[:email_notification] == "email_notification"
			event = calendar_obj.update(title: params[:title],description: params[:description], location: params[:location],
													when:{start_time: Time.local(startDate[0],startDate[1],startDate[2],startTime[0],startTime[1],0).strftime("%s"),
													end_time: Time.local(endDate[0],endDate[1],endDate[2],endTime[0],endTime[1],0).strftime("%s")},
													participants: participants,calendar_id: ENV["CRM_CALENDAR_ID"], 
													notify_participants: true,notifications: [{type: "email", minutes_before_event: "#{params[:email_before]}",subject: email_notification_title,
													body: email_notification_title}])	
		else
			event = calendar_obj.update(title: params[:title], description: params[:description], location: params[:location],
													when:{start_time: Time.local(startDate[0],startDate[1],startDate[2],startTime[0],startTime[1],0).strftime("%s"),
													end_time: Time.local(endDate[0],endDate[1],endDate[2],endTime[0],endTime[1],0).strftime("%s")},
													participants: participants,calendar_id: ENV["CRM_CALENDAR_ID"], 
													notify_participants: true)	
		end
		
		conn.execute("update events set title=?,description=?,location=?,start_date=?,
							  start_time=?,end_date=?,end_time=?,participants_list=?,
							  names_list=?,phones_list=?,email_remind=?,email_minutes=?
							  where id=?", 
							  params[:title],params[:description],params[:location],params[:start_date],
							  params[:start_time],params[:end_date],params[:end_time],participant_emails,
							  participant_names,participant_phones,params[:email_notification],
							  params[:email_before],params[:id])		
	end
	
	connection.end_connection()	
											 
	redirect to("/display_events?limit=0")
end

get '/display_events' do
	connection = DB.new()
	conn = connection.get_connection()
	limit = params[:limit]
	events_all = conn.execute( "SELECT * FROM events")
	events = conn.execute( "SELECT * FROM events WHERE id NOT IN ( SELECT id FROM events
											ORDER BY start_date DESC LIMIT #{limit} ) ORDER BY start_date DESC LIMIT #{settings.limit}" )
	tops = events_all.length + 1
	connection.end_connection()
	erb :display_events, :layout => :layout, :locals => {:events => events, :limit => limit, :tops => tops}
end

get '/delete_event' do
	events_cls = Events.new()
	event = events_cls.event_object().find(params[:id])
	event.destroy
	connection = DB.new()
	conn = connection.get_connection()
	conn.execute("delete from events where id = '#{params[:id]}'")
	connection.end_connection()
	redirect to("/display_events?limit=0")
end

get '/update_event' do
	connection = DB.new()
	conn = connection.get_connection()
	event = conn.execute("select * from events where id = '#{params[:id]}'")
	contacts = conn.execute( "select * from contacts")
	connection.end_connection()
	action = "update"
	erb :create_event, :layout => :layout, :locals => {:event => event,:contacts => contacts, :action => action}
end
