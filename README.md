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
# To read .env files
$ gem install dotenv

# Makes http fun again
$ gem install httparty

# Shoes 4 GUI Toolkit
$ gem install shoes --pre

```

## Usage

Run the app using the `shoes` command:

```bash
$ shoes Shoes_Mail_Client.rb
```

When successfull, it will display a GUI window showing the first 5 emails from the inbox.

## Read the blog post
[_why day 2022](https://www.nylas.com/blog/_why-day-2022-dev/)

## Learn more

Visit our [Nylas Email API documentation](https://developer.nylas.com/docs/connectivity/email/) to learn more.
