## Introduction

Omni-Cal is a tool I wrote for personal use. It places the events I'm registered to at Meetup.com on my Google Calendar. It's hooked up to Heroku Scheduler and runs every 10 minutes, effectively providing near-real-time synchronization between the two calendars.

## Purpose

While this sort of thing can be easily configured with iCal feeds, which both Meetup.com and Google support, I found Google Calendar's implementation of it to be unreliable. Events can take anywhere from 8 to 24 hours to show up (or disappear from) the calendar, which means that events I RSVP to may not appear on my calendar until the next day. This made my personal planning difficult, and I needed the updates to be much more frequent, so I wrote this tool.

## How It Works

The operation is fairly straight-forward at a high level. Omni-Cal grabs a list of events from Meetup.com (using their API over HTTP) and Google Calendar (using the [Google Ruby Client](https://github.com/google/google-api-ruby-client), which is a wrapper around the Google API). It then compares them and resolves the differences, treating the Meetup event list as the "master" list:

1. If a Meetup event is not on the calendar, it gets added
2. If a Calendar event is not in the Meetup event list, it gets removed
3. If an event exists in both lists, details (time, location, etc.) are updated to ensure accuracy.

Once all this is done, the requests are compiled as a batch and pushed to Google Calendar.

## Authentication

Both APIs require authentication. Meetup provides an API key that can simply be sent as a query parameter during the HTTP GET request. Google Calendar API on the other hand requires OmniAuth, which provides three different types of authentication "flows" depending on the type of the application:

1. Web server: This is the most common form of OAuth flow on the web, where users are presented with a consent screen asking if the third-party application can use their Google account to log in.
2. Service account: Used by server-side flows where the server will communicate with Google servers behind the scenes, and users will not interact with the application. This is what Omni-Cal uses.
3. Installed application: Used for applications that are installed on a device such as a computer, a cell phone, or a tablet.

More information on OmniAuth service accounts can be found [here](https://developers.google.com/identity/protocols/OAuth2ServiceAccount).

## License

This project uses the GPLv3 license.