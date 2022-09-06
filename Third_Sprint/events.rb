# frozen_string_literal: true

# Call the parent file
require File.expand_path('../nylas_crm.rb', __FILE__)

# Call the next class file
require_relative 'email'

# Events class that will handle all events related operations
class Events < Nylas_class
  # When we create an object of this class, we will have access
  # to calendar and events functions. We'll also access a newly
  # created calendar.
  def initialize
    @calendar = @@nylas_crm.calendars
    @events = @@nylas_crm.events.where(calendar_id: ENV['CRM_CALENDAR_ID'])
  end

  # Return the calendar object
  def create_calendar
    @calendar
  end

  # Return all the events
  def return_events
    @events
  end

  # Return the events object
  def event_object
    @@nylas_crm.events
  end
end

# This will create a new calendar on our provider account
get '/create_calendar' do
  # We're reading the .env file to make sure the calendar is not there
  if ENV['CRM_CALENDAR_ID'].nil?
    # Create a new calendar class instance
    calendar_cls = Events.new
    # Create a new calendar object
    calendar_obj = calendar_cls.create_calendar
    # Create a new calendar specifying it's name and description
    calendar = calendar_obj.create(
      name: settings.calendar_name.to_s,
      description: settings.calendar_description.to_s
    )
    # Open the .env file to add the calendar id of the newly created calendar
    File.open('.env', 'a') { |f| f.write "export CRM_CALENDAR_ID=#{calendar.id}" }
    erb :calendar_created, layout: :layout,
                           locals: { message: "The #{settings.calendar_name} has been created." }
  # Don't created again. It already exists.
  else
    erb :calendar_created, layout: :layout,
                           locals: { message: "The #{settings.calendar_name} already exists." }
  end
end

# Page to create an event with all the necessary fields
get '/create_event' do
  # Create a new database object
  connection = DB.new
  # Open the database
  conn = connection.get_connection
  # Select all fields from the contacts table
  contacts = conn.execute('select * from contacts')
  # Select all fields from the events table using the calendar id
  event = conn.execute("select * from events where id = '#{params[:id]}'")
  # Close the DB connection
  connection.end_connection
  # Specify that we're creating a new event
  action = 'create'
  # Call the create_event.erb page
  erb :create_event, layout: :layout, locals: { contacts: contacts, event: event, action: action }
end

# This page will create or update a new events
post '/create_update_event' do
  # Create a new events object
  calendar_cls = Events.new
  # Create a new DB connection
  connection = DB.new
  # Return the connection object
  conn = connection.get_connection

  # Fill in all parameters
  startDate = params[:start_date].split(/-/)
  startTime = params[:start_time].split(/:/)
  endDate = params[:end_date].split(/-/)
  endTime = params[:end_time].split(/:/)
  participants_list = params[:participants_list].split(/;/)
  names_list = params[:names_list].split(/;/)
  phones_list = params[:phones_list].split(/;/)
  participants = []
  participant_emails = ''
  participant_names = ''
  participant_phones = ''

  i = 0
  # Get the participants emails, names and phones
  participants_list.each do |participant|
    participants.push({ name: (names_list[i]).to_s, email: participant.to_s })
    participant_emails = "#{participant_emails}#{participant}/"
    participant_names = "#{participant_names}#{names_list[i]}/"
    participant_phones = "#{participant_phones}#{phones_list[i]}/"
    i += 1
  end

  participant_emails = participant_emails.chomp('/')
  participant_names = participant_names.chomp('/')
  participant_phones = participant_phones.gsub(/\s/, '')
  participant_phones = participant_phones.gsub("\/", '')

  # Define the title of the email notification
  email_notification_title = "#{params[:title]} starts in #{params[:email_before]} minutes"

  # If we're creating an event
  if params[:action] == 'create'
    # Create an event object
    calendar_obj = calendar_cls.events_create
    # Are we using email notification?
    if params[:email_notification] == 'email_notification'
      # Create the event using email notification
      event = calendar_obj.create(title: params[:title], description: params[:description], location: params[:location], when: { start_time: Time.local(startDate[0], startDate[1], startDate[2], startTime[0], startTime[1], 0).strftime('%s'),
                                                                                                                                 end_time: Time.local(endDate[0], endDate[1], endDate[2], endTime[0],
                                                                                                                                                      endTime[1], 0).strftime('%s') },
                                  participants: participants, calendar_id: ENV['CRM_CALENDAR_ID'],
                                  notify_participants: true, notifications: [{ type: 'email', minutes_before_event: params[:email_before].to_s, subject: email_notification_title,
                                                                               body: email_notification_title }])
    else
      # Create the event without using email notification
      event = calendar_obj.create(title: params[:title], description: params[:description], location: params[:location],
                                  when: { start_time: Time.local(startDate[0], startDate[1], startDate[2], startTime[0], startTime[1], 0).strftime('%s'),
                                          end_time: Time.local(endDate[0], endDate[1], endDate[2], endTime[0],
                                                               endTime[1], 0).strftime('%s') },
                                  participants: participants, calendar_id: ENV['CRM_CALENDAR_ID'],
                                  notify_participants: true)
    end
    # Create a new record on the events table
    conn.execute("insert into events(id,title,description,location,start_date,
                             start_time,end_date,end_time,participants_list,
                             names_list,phones_list,email_remind,email_minutes) values
                             (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                 event.id, params[:title], params[:description],
                 params[:location], params[:start_date], params[:start_time],
                 params[:end_date], params[:end_time], participant_emails,
                 participant_names, participant_phones, params[:email_notification],
                 params[:email_before])
  # We're updating an event
  else
    # Find the event by it's id
    event = events_cls.event_object.find(params[:id])
    # Are we using email notification?
    # Create the event using email notification
    if params[:email_notification] == 'email_notification'
      event = calendar_obj.update(title: params[:title], description: params[:description], location: params[:location],
                                  when: { start_time: Time.local(startDate[0], startDate[1], startDate[2], startTime[0], startTime[1], 0).strftime('%s'),
                                          end_time: Time.local(endDate[0], endDate[1], endDate[2], endTime[0],
                                                               endTime[1], 0).strftime('%s') },
                                  participants: participants, calendar_id: ENV['CRM_CALENDAR_ID'],
                                  notify_participants: true, notifications: [{ type: 'email', minutes_before_event: params[:email_before].to_s, subject: email_notification_title,
                                                                               body: email_notification_title }])
    else
      # Create the event without using email notification
      event = calendar_obj.update(title: params[:title], description: params[:description], location: params[:location],
                                  when: { start_time: Time.local(startDate[0], startDate[1], startDate[2], startTime[0], startTime[1], 0).strftime('%s'),
                                          end_time: Time.local(endDate[0], endDate[1], endDate[2], endTime[0],
                                                               endTime[1], 0).strftime('%s') },
                                  participants: participants, calendar_id: ENV['CRM_CALENDAR_ID'],
                                  notify_participants: true)
    end
    # Create the record on the events table
    conn.execute("update events set title=?,description=?,location=?,start_date=?,
                             start_time=?,end_date=?,end_time=?,participants_list=?,
                             names_list=?,phones_list=?,email_remind=?,email_minutes=?
                             where id=?",
                 params[:title], params[:description], params[:location], params[:start_date],
                 params[:start_time], params[:end_date], params[:end_time], participant_emails,
                 participant_names, participant_phones, params[:email_notification],
                 params[:email_before], params[:id])
  end
  # Close the connection
  connection.end_connection
  # Call the display_events page setting the limit as 0
  redirect to('/display_events?limit=0')
end

# Show events
get '/display_events' do
  # Create a new DB connection
  connection = DB.new
  # Return the connection object
  conn = connection.get_connection
  # Get the limit for pagination (how many item to display)
  limit = params[:limit]
  # Select all fields from the events table
  events_all = conn.execute('SELECT * FROM events')
  # Select all fields from the events table using limits to help with pagination
  events = conn.execute("SELECT * FROM events WHERE id NOT IN ( SELECT id FROM events
                                           ORDER BY start_date DESC LIMIT #{limit} ) ORDER BY start_date DESC LIMIT #{settings.limit}")
  # Add one to the total count of records
  tops = events_all.length + 1
  # Close the DB connection
  connection.end_connection
  # Call the display_events.erb page
  erb :display_events, layout: :layout, locals: { events: events, limit: limit, tops: tops }
end

# Delete an event using the id
get '/delete_event' do
  # Create a new event object
  events_cls = Events.new
  # Find the event by id
  event = events_cls.event_object.find(params[:id])
  # and delete it
  event.destroy
  # Create a new DB connaction
  connection = DB.new
  # Return the connection object
  conn = connection.get_connection
  # Delete from the events contacts using the id
  conn.execute("delete from events where id = '#{params[:id]}'")
  # Close the connection
  connection.end_connection
  # Call the display_events page setting the limit as 0
  redirect to('/display_events?limit=0')
end

# Prepare parameters for update
get '/update_event' do
  # Create a new DB connaction
  connection = DB.new
  # Return the connection object
  conn = connection.get_connection
  # Select all fields from the events table by id
  event = conn.execute("select * from events where id = '#{params[:id]}'")
  # Select all fields from the contacts table
  contacts = conn.execute('select * from contacts')
  # Close the connection
  connection.end_connection
  # Set the action to update
  action = 'update'
  # Call the create_event page
  erb :create_event, layout: :layout, locals: { event: event, contacts: contacts, action: action }
end
