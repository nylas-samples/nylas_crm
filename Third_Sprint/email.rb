# frozen_string_literal: true

# Call the parent file
require File.expand_path('../nylas_crm.rb', __FILE__)

# Emails class that will handle all email related operations
class Emails < Nylas_class
  def initialize
    @emails = @@nylas_crm.messages
  end

  def return_emails
    @emails
  end

  def return_send
    @@nylas_crm
  end

  def return_labels
    @@nylas_crm.labels
  end
end

# Page to setup the custom mail merge fields
get '/mail_merge_fields' do
  # Create a new database object
  connection = DB.new
  # Return the connection object
  conn = connection.get_connection
  # Select all fields from the merge_fields table
  result = conn.execute('select * from merge_fields')
  # # Close the DB connection
  connection.end_connection
  # Call the mail_merge_fields.erb page
  erb :mail_merge_fields, layout: :layout, locals: { mail_merge_fields: result }
end

# Process the custom fields for mail merge
post '/mail_merge_fields' do
  # Create a new database object
  connection = DB.new
  # Return the connection object
  conn = connection.get_connection
  # Delete all records from the merge_fields table
  conn.execute('delete from merge_fields')
  # Insert the parameters into the merge_fields table
  conn.execute("insert into merge_fields(field1,description1,field2,description2,
			              field3,description3,field4,description4,field5,description5) values
			              (?,?,?,?,?,?,?,?,?,?)",
               params[:field_one], params[:field_one_desc],
               params[:field_two], params[:field_two_desc],
               params[:field_three], params[:field_three_desc],
               params[:field_four], params[:field_four_desc],
               params[:field_five], params[:field_five_desc])
  # Close the DB connection
  connection.end_connection
  # Redirects to main page
  redirect to('/')
end

# Page to setup the mail environment
get '/send_email' do
  # Create a new database object
  connection = DB.new
  # Return the connection object
  conn = connection.get_connection
  # Select all fields from contacts
  contacts = conn.execute('select * from contacts')
  # Close the DB connection
  connection.end_connection
  # Call the send_email.erb page
  erb :send_email, layout: :layout, locals: { contacts: contacts }
end

# Page for email reply
get '/reply_email' do
  # Create a new email object
  emails_cls = Emails.new
  # Return the messages object
  emails_obj = emails_cls.return_emails
  # Find the email by Id
  email = emails_obj.find(params[:email])
  # Call the reply_email.erb page
  erb :reply_email, layout: :layout, locals: { email: email }
end

# Delete an email
get '/delete_email' do
  # Create a new email object
  emails_cls = Emails.new
  # Create a hash to store labels
  labelsDict = {}
  labels = emails_cls.return_labels
  labels.each do |label|
    labelsDict[label.name] = label.id
  end
  # Return the messages object
  emails_obj = emails_cls.return_emails
  # Find the email by Id
  email = emails_obj.find(params[:email])
  # Update the label of the email
  email.update(label_ids: [labelsDict['trash']])
  # Save changes
  email.save
  # Call the display_emails page
  redirect to('/display_emails')
end

# Process the parameters to send an email
post '/send_email' do
  # Create a new email object
  emails_cls = Emails.new
  # Return an instance of the Nylas object
  emails_obj = emails_cls.return_send
  # Get participants emails and split them if more than one
  participants_list = params[:participants_list].split(/;/)
  # Get participants names and split them if more than one
  names_list = params[:names_list].split(/;/)
  participants = []
  i = 0
  # For each participant add name and email to an array
  participants_list.each do |participant|
    participants.push({ name: (names_list[i]).to_s, email: participant.to_s })
    i += 1
  end
  # Remove the <div> and </div> from the email body
  body = params[:body].gsub(/<div>/, '').gsub(%r{</div>}, '')

  # We are composing an email
  if params[:reply_to].nil?
    emails_obj.send!(to: participants, subject: params[:subject], body: body).to_h
  # We are replying to an email
  else
    emails_obj.send!(to: participants, subject: params[:subject], reply_to: params[:reply_to], body: body).to_h
  end
  # Call the display_emails page
  redirect to('/display_emails')
end

# Page to setup the mail merge contacts environment
# Here we define the custom fields tied to a contact
get '/mail_merge_contacts' do
  # Create a new DB connection
  connection = DB.new
  # Return the connection object
  conn = connection.get_connection
  # Select all fields from contacts
  contacts = conn.execute('select * from contacts')
  # Select all fields from merge_mail
  merge = conn.execute('select * from merge_mail')
  # Select all fields from merge_fields
  fields = conn.execute('select * from merge_fields')
  # Close the DB connection
  connection.end_connection
  # Call the mail_merge_contacts.erb page
  erb :mail_merge_contacts, layout: :layout, locals: { contacts: contacts, merge: merge, fields: fields }
end

# Process the mail merge contact parameters
post '/mail_merge_contacts' do
  # Create a new DB connection
  connection = DB.new
  # Return the connection object
  conn = connection.get_connection
  # Update the record in the merge_mail table related to a contact id
  conn.execute("update merge_mail set field1=?, field2=?, field3=?,field4=?,field5=?
						  where id=?",
               "#{params[:field1_name]}:#{params[:field1]}",
               "#{params[:field2_name]}:#{params[:field2]}",
               "#{params[:field3_name]}:#{params[:field3]}",
               "#{params[:field4_name]}:#{params[:field4]}",
               "#{params[:field5_name]}:#{params[:field5]}",
               params[:id])
  # Close the DB connection
  connection.end_connection
  # Call the mail_merge_contacts page
  redirect to('/mail_merge_contacts')
end

# Show emails
get '/display_emails' do
  # Create a new email object
  emails_cls = Emails.new
  # Return the messages object
  emails_obj = emails_cls.return_emails
  # Create a new DB connection
  connection = DB.new
  # Return the connection object
  conn = connection.get_connection
  # If the email_limit is empty
  # it means we want to fetch new emails
  if params[:email_limit].nil?
    # Read inbox emails
    emails = emails_obj.where(in: 'inbox').limit(settings.fetch_emails)
    # Delete all fields from the emails table
    conn.execute('delete from emails')
    # Loop through each email
    emails.each do |email|
      # and save it to the database
      conn.execute("insert into emails(id,date,subject,name,email,unread)
								 values (?,?,?,?,?,?)",
                   email.id, email.date.to_s, email.subject,
                   email.from.first.name,
                   email.from.first.email, email.unread.to_s)
    end
    email_limit = 0
  # Select all fields from the email table
  # Select all fields from the emails table using limits to help with pagination
  # Add one to the total count of records
  # Close the DB connection
  else
    # When receiving the email_limit parameter it means we not fetching new emails
    email_limit = params[:email_limit]
    # Select * from the emails table
    # Select all fields from the emails table using limits to help with pagination
    # Add one to the total count of records
    # Close the DB connection
  end
  emails_all = conn.execute('SELECT * FROM emails')
  emails = conn.execute("SELECT * FROM emails WHERE id NOT IN ( SELECT id FROM emails
											ORDER BY date DESC LIMIT #{email_limit} ) ORDER BY date DESC LIMIT #{settings.email_limit}")
  tops = emails_all.length + 1
  connection.end_connection
  # Call the display_emails.erb page
  erb :display_emails, layout: :layout, locals: { emails: emails, email_limit: email_limit, tops: tops }
end

# Read the email details
get '/read_email' do
  # Create a new email object
  emails_cls = Emails.new
  # Return the messages object
  emails_obj = emails_cls.return_emails
  # Get email detail using its Id
  email = emails_obj.find(params[:email])
  # Update the email label
  email.update(unread: false)
  # Call the read_email.erb page
  erb :read_email, layout: :layout, locals: { email: email }
end

# Define information to send an email via mail merge
get '/send_mail_merge' do
  # Create a new DB connection
  connection = DB.new
  # Return the connection object
  conn = connection.get_connection
  # Select all fields from the contacts table
  contacts = conn.execute('select * from contacts')
  # Select all fields from the merge_mail table
  merge = conn.execute('select * from merge_fields')
  # Close the DB connection
  connection.end_connection
  # Call the send_mail_merge.erb page
  erb :send_mail_merge, layout: :layout, locals: { contacts: contacts, merge: merge }
end

# Process the information to send an email via mail merge
post '/send_mail_merge' do
  # Create a new email object
  emails_cls = Emails.new
  # Return the messages object
  emails_obj = emails_cls.return_send
  # Create a new DB connection
  connection = DB.new
  # Return the connection object
  conn = connection.get_connection
  # Get participants emails and split them if more than one
  participants_list = params[:participants_list].split(/;/)
  # Get participants names and split them if more than one
  names_list = params[:names_list].split(/;/)
  # Get participants ids and split them if more than one
  ids_list = params[:ids_list].split(/;/)
  i = 0
  # Select all fields from the merge_mail table
  merge_fields = conn.execute('select field1, field2, field3, field4, field5 from merge_fields')
  # Looo through each participant
  participants_list.each do |participant|
    participants = []
    # For each participant add name and email to an array
    participants.push({ name: (names_list[i]).to_s, email: participant.to_s })
    # Select some fields from the contacts table
    contacts = conn.execute(
      'select given_name, nickname, surname, birthday, physical_address from contacts where id = ?', ids_list[i]
    )
    # Select all fields from the merge_mail table
    merge_mail = conn.execute('select field1, field2, field3, field4, field5 from merge_mail where id = ?',
                              ids_list[i])
    # Get the subject
    subject = params[:subject]
    # Remove the <div> and </div> from the email body
    body = params[:body].gsub(/<div>/, '').gsub(%r{</div>}, '')
    begin
      # Replace the words between brackets with the information from the contact table
      subject = subject.gsub(/{given_name}/, contacts[0][0])
      body = body.gsub(/{given_name}/, contacts[0][0])
    rescue StandardError => e
      subject = subject.gsub(/{given_name}/, '<Given Name not found, please update>')
      body = body.gsub(/{given_name}/, '<Given Name not found, please update>')
    end
    begin
      subject = subject.gsub(/{nickname}/, contacts[0][1])
      body = body.gsub(/{nickname}/, contacts[0][1])
    rescue StandardError => e
      subject = subject.gsub(/{nickname}/, '<Nickname not found, please update>')
      body = body.gsub(/{nickname}/, '<Nickname not found, please update>')
    end
    begin
      subject = subject.gsub(/{surname}/, contacts[0][2])
      body = body.gsub(/{surname}/, contacts[0][2])
    rescue StandardError => e
      subject = subject.gsub(/{surname}/, '<Surname not found, please update>')
      body = body.gsub(/{surname}/, '<Surname not found, please update>')
    end
    begin
      subject = subject.gsub(/{birthday}/, contacts[0][3])
      body = body.gsub(/{birthday}/, contacts[0][3])
    rescue StandardError => e
      subject = subject.gsub(/{birthday}/, '<Birthday not found, please update>')
      body = body.gsub(/{birthday}/, '<Birthday not found, please update>')
    end
    begin
      physical_address = contacts[0][4]
      street = physical_address.scan(/(?<=street_address:).+/)
      country = physical_address.scan(/(?<=country:)(.*?,)/)
      city = physical_address.scan(/(?<=city:)(.*?,)/)
      postal = physical_address.scan(/(?<=postal_code:)(.*?,)/)
      state = physical_address.scan(/(?<=state:)(.*?,)/)
      begin
        city = city[0][0].gsub(/,/, '')
      rescue StandardError => e
        city[0] = ''
      end
      begin
        country = country[0][0].gsub(/,/, '')
      rescue StandardError => e
        country[0] = ''
      end
      begin
        postal = postal[0][0].gsub(/,/, '')
      rescue StandardError => e
        postal[0] = ''
      end
      begin
        state = state[0][0].gsub(/,/, '')
      rescue StandardError => e
        state[0] = ''
      end
      address = if street[0].to_s != ''
                  "#{street[0]}, #{city}, #{state}, #{country}, #{postal}"
                else
                  '<Address not found. Please update>'
                end
      subject = subject.gsub(/{physical_address}/, address)
      body = body.gsub(/{physical_address}/, address)
    rescue StandardError => e
    end

    # Grab the information from the merge_mail table
    field1 = merge_mail[0][0].to_s.split(':')
    field1 = field1[1]
    field2 = merge_mail[0][1].to_s.split(':')
    field2 = field2[1]
    field3 = merge_mail[0][2].to_s.split(':')
    field3 = field3[1]
    field4 = merge_mail[0][3].to_s.split(':')
    field4 = field4[1]
    field5 = merge_mail[0][4].to_s.split(':')
    field5 = field5[1]

    # Replace all "custom" mail merge fields with the merge_mail table values
    begin
      subject = subject.gsub(/{#{merge_fields[0][0]}}/, field1)
      body = body.gsub(/{#{merge_fields[0][0]}}/, field1)
    rescue StandardError => e
      subject = subject.gsub(/{#{merge_fields[0][0]}}/, "<#{merge_fields[0][0]} not found. Please update>")
      body = body.gsub(/{#{merge_fields[0][0]}}/, "<#{merge_fields[0][0]} not found. Please update>")
    end
    begin
      subject = subject.gsub(/{#{merge_fields[0][1]}}/, field2)
      body = body.gsub(/{#{merge_fields[0][1]}}/, field2)
    rescue StandardError => e
      subject = subject.gsub(/{#{merge_fields[0][1]}}/, "<#{merge_fields[0][1]} not found. Please update>")
      body = body.gsub(/{#{merge_fields[0][1]}}/, "<#{merge_fields[0][1]} not found. Please update>")
    end
    begin
      subject = subject.gsub(/{#{merge_fields[0][2]}}/, field3)
      body = body.gsub(/{#{merge_fields[0][2]}}/, field3)
    rescue StandardError => e
      subject = subject.gsub(/{#{merge_fields[0][2]}}/, "<#{merge_fields[0][2]} not found. Please update>")
      body = body.gsub(/{#{merge_fields[0][2]}}/, "<#{merge_fields[0][2]} not found. Please update>")
    end
    begin
      subject = subject.gsub(/{#{merge_fields[0][3]}}/, field4)
      body = body.gsub(/{#{merge_fields[0][3]}}/, field4)
    rescue StandardError => e
      subject = subject.gsub(/{#{merge_fields[0][3]}}/, "<#{merge_fields[0][3]} not found. Please update>")
      body = body.gsub(/{#{merge_fields[0][3]}}/, "<#{merge_fields[0][3]} not found. Please update>")
    end
    begin
      subject = subject.gsub(/{#{merge_fields[0][4]}}/, field5)
      body = body.gsub(/{#{merge_fields[0][4]}}/, field5)
    rescue StandardError => e
      subject = subject.gsub(/{#{merge_fields[0][4]}}/, "<#{merge_fields[0][4]} not found. Please update>")
      body = body.gsub(/{#{merge_fields[0][4]}}/, "<#{merge_fields[0][4]} not found. Please update>")
    end

    i += 1
    # Send email to all participants
    emails_obj.send!(to: participants, subject: subject, body: body).to_h
  end
  # Call the display_emails page
  redirect to('/display_emails')
end
