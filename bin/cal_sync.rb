require 'net/http'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'
require 'open-uri'
require 'active_support/all'

def sync

  client = Google::APIClient.new(application_name: "Calendar Sync", application_version: "0.0.1")
  batch = Google::APIClient::BatchRequest.new
  private_key = ENV['GOOGLE_CALENDAR_KEY']
  key = OpenSSL::PKey::RSA.new private_key, 'notasecret'
  client.authorization = Signet::OAuth2::Client.new(
                      :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
                      :audience             => 'https://accounts.google.com/o/oauth2/token',
                      :scope                => 'https://www.googleapis.com/auth/calendar',
                      :issuer               => ENV['GOOGLE_SERVICE_ACCOUNT'],
                      :signing_key          => key )
  client.authorization.fetch_access_token!
  api = client.discovered_api('calendar', 'v3')
  google_events = client.execute(:api_method => api.events.list,
                                 :parameters => { 'calendarId'   => ENV['GOOGLE_CALENDAR_ID'],
                                                  'timeMin'      => DateTime.now,
                                                  'timeMax'      => 2.months.from_now.to_datetime } ).data['items'].to_a
  time_range = "#{Time.now.to_datetime.to_i * 1000},#{2.months.from_now.to_datetime.to_i * 1000}"
  meetup_url = "https://api.meetup.com/2/events?&sign=true&key=#{ENV['MEETUP_API_KEY']}&photo-host=public&rsvp=yes&member_id=#{ENV['MEETUP_MEMBER_ID']}&time=#{time_range}"
  meetup_events = JSON.parse(URI.parse(meetup_url).read)['results']

  meetup_events.each do |meetup_event|
    if !google_events.any? {|g| g.extended_properties.private["unique_id"] == meetup_event["id"] }
      body = { 'summary'            => meetup_event["name"],
               'description'        => meetup_event["description"],
               'location'           => meetup_event["venue"]["address_1"],
               'timeZone'           => 'America/Chicago',
               'start'              => { 'dateTime' => Time.at(meetup_event["time"].to_i / 1000).to_datetime.to_s },
               'end'                => { 'dateTime' => Time.at((meetup_event["time"].to_i / 1000) + (meetup_event["duration"].to_i / 1000)).to_datetime.to_s},
               'extendedProperties' => { 'private'  => { 'unique_id' => meetup_event["id"] } } 
             }
      batch.add( :api_method => api.events.insert,
                 :parameters => { 'calendarId'   => ENV['GOOGLE_CALENDAR_ID'] },
                 :headers    => { 'Content-Type' => 'application/json' },
                 :body       => JSON.dump(body) )
    else
      google_event = google_events.find {|g| g.extended_properties.private["unique_id"] == meetup_event["id"]}
      body = { 'summary'            => meetup_event["name"],
               'description'        => meetup_event["description"],
               'location'           => meetup_event["venue"]["address_1"],
               'start'              => { 'dateTime' => Time.at(meetup_event["time"].to_i / 1000).to_datetime.to_s },
               'end'                => { 'dateTime' => Time.at((meetup_event["time"].to_i / 1000) + (meetup_event["duration"].to_i / 1000)).to_datetime.to_s},
               'extendedProperties' => { 'private'  => { 'unique_id' => meetup_event["id"] } }
             }
      batch.add( :api_method => api.events.update,
                 :parameters => { 'calendarId'   => ENV['GOOGLE_CALENDAR_ID'],
                                  'eventId'      =>  google_event.id },
                 :headers    => { 'Content-Type' => 'application/json' },
                 :body       => JSON.dump(body))
    end
  end

  google_events.each do |google_event|
    if !meetup_events.any? {|r| r["id"] == google_event.extended_properties.private["unique_id"] }
      batch.add( :api_method => api.events.delete,
                 :parameters => { 'calendarId'   => ENV['GOOGLE_CALENDAR_ID'],
                                  'eventId'      =>  google_event.id },
                 :headers    => { 'Content-Type' => 'application/json' })
    end
  end

  response = client.execute(batch)
  p response.status

end