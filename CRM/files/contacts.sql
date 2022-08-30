DROP TABLE IF EXISTS contacts;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS merge_fields;
DROP TABLE IF EXISTS merge_mail;
CREATE TABLE contacts(id TEXT NOT NULL, given_name TEXT, middle_name TEXT, nickname TEXT, surname TEXT, birthday TEXT,company_name TEXT, notes TEXT, picture_url TEXT, picture TEXT, emails TEXT, phone_numbers TEXT, physical_address TEXT, job_title TEXT)
CREATE TABLE events(id TEXT NOT NULL, title TEXT, description TEXT, location TEXT, start_date TEXT, start_time TEXT, end_date TEXT, end_time TEXT, participants_list TEXT, names_list TEXT, phones_list TEXT, email_remind CHAR, email_minutes TEXT)
CREATE TABLE merge_fields(field1 TEXT, description1 TEXT, field2 TEXT, description2 TEXT,field3 TEXT, description3 TEXT,field4 TEXT, description4 TEXT,field5 TEXT, description5 TEXT)
CREATE TABLE merge_mail(id TEXT, email TEXT, field1 TEXT, field2 TEXT, field3 TEXT, field4 TEXT, field5 TEXT)
CREATE TABLE emails(id TEXT, date TEXT, subject TEXT, name TEXT, email TEXT, unread TEXT)
