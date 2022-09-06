DROP TABLE IF EXISTS contacts;
DROP TABLE IF EXISTS events;
CREATE TABLE contacts(id TEXT NOT NULL, given_name TEXT, middle_name TEXT, nickname TEXT, surname TEXT, birthday TEXT,company_name TEXT, notes TEXT, picture_url TEXT, picture TEXT, emails TEXT, phone_numbers TEXT, physical_address TEXT, job_title TEXT)
CREATE TABLE events(id TEXT NOT NULL, title TEXT, description TEXT, location TEXT, start_date TEXT, start_time TEXT, end_date TEXT, end_time TEXT, participants_list TEXT, names_list TEXT, phones_list TEXT, email_remind CHAR, email_minutes TEXT)
