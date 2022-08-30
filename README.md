# Nylas CRM

This project will show you how to create a very basic CRM implemented some interestung capabilities like CRUD for Contacts, Events and Emails and even Mail Merge.

## Setup

### System dependencies

- Ruby 3.1.1 or greater

### Gather environment variables

You'll need the following values:

```text
CLIENT_ID = ""
CLIENT_SECRET = ""
ACCESS_TOKEN = ""
```

Add the above values to a new `.env` file:

```bash
$ touch .env # Then add your env variables
```

### Install dependencies

```bash
$ gem install dotenv
$ gem install sinatra
$ gem install sinatra-base
$ gem install sinatra-contrib
$ gem install sqlite3
$ gem install nylas

```

## Usage

Clone the repository. Navigate to the `CRM` folder and open the `config.yml` file, which will contain the following:

```
crm_name: Nylas' CRM
calendar_name: Nylas CRM Calendar
calendar_description: Calendar for the Nylas CRM
background_image: NylasDesktop.png 
background_color: 4169E0
panel_color: bg-blue-300
panel_border: border-blue-300
limit: 4
email_limit: 10
fetch_emails: 30
```

This is our configuration file. If you want your CRM to display a different name and have a different welcome image, change `crm_name` and `background_image` accordingly. (The image must be inside the `public` folder).

Change the `calendar_name` variable if you want your calendar to be named differently.

Once your happy with the configuration, type the following command on a terminal window: 

```bash
$ ruby nylas_crm.rb
```

And go to `http://localhost:4567`

The first you run the app, you need to select a couple of links.

First, run `Contacts --> Sync Contacts`. This will create the db, setup all the tables and also sync the contacts.

Then run `Events --> Create CRM Calendar`. This will create a new calendar and save the id on your `.env` file.

After that, you can run whatever you want.

## Read the blog post

## Learn more
