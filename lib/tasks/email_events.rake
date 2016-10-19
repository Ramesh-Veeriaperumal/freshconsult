namespace :email_events do

  MAILGUN_API_KEY = YAML.load_file(File.join(Rails.root, 'config', 'mailgun.yml'))[Rails.env]['api_key']

  desc "Tracking events of email in mailgun"
  task :mailgun, [:domain] => [:environment] do |t, args|
    include Redis::OthersRedis
    include Redis::RedisKeys

    loop do
      track_mailgun_events(args['domain'])
      sleep(1.hours)
    end
  end

end

def track_mailgun_events(domain)
  last_synced_key = MAILGUN_EVENT_LAST_SYNC % {:domain => domain }
  last_synced_time = get_others_redis_key(last_synced_key)
  last_sync = last_synced_time ? last_synced_time : update_last_sync_time(domain)
  end_time = (last_sync.to_datetime + 1.hours).to_datetime.strftime("%a, %d %b %Y %H:%M:%S %z")

  event_url = "@api.mailgun.net/v3/#{domain}/events"
  response = JSON.parse(fetch_api(event_url, last_sync, end_time))

  while response["items"].present? do
    log_events(response["items"])
    event_url = response["paging"]["next"].gsub("https://", "@")
    response = JSON.parse(fetch_api(event_url))
  end
  update_last_sync_time(last_synced_key, end_time)
end

def update_last_sync_time(last_synced_key, time=nil)
  last_synced_time = time ? time : (DateTime.now - 1.hours).to_datetime.strftime("%a, %d %b %Y %H:%M:%S %z")
  set_others_redis_key(last_synced_key, last_synced_time)
  last_synced_time
end

def fetch_api(event_url, last_sync = nil, end_time = nil)
  if (last_sync and end_time)
    response = RestClient.get("https://api:#{MAILGUN_API_KEY}"\
      "#{event_url}", :params => { :'begin' => last_sync, :'end' => end_time, :'ascending' => 'yes', :'limit' => 10, :'pretty' => 'yes'})
  else
    response = RestClient.get("https://api:#{MAILGUN_API_KEY}"\
      "#{event_url}")
  end
end

def log_events(events)
  events.each do |event_obj|
    custom_variables = event_obj["user-variables"]["unique_args"]
    mailgun_events_logger.info "Event type: #{event_obj["event"]}\nMessage-Id: #{event_obj["message"]["headers"]["message-id"]}\nSubject: #{event_obj["message"]["headers"]["subject"]}\nRecipient : #{event_obj["recipient"]}\nCustom variables: #{custom_variables.inspect}\nTimestamp: #{event_obj["timestamp"]}\nFrom: #{event_obj["message"]["headers"]["from"]}\n"
  end
end

def mailgun_events_logger
  @mailgun_events_logger ||= CustomLogger.new("#{Rails.root}/log/mailgun_events.log")
end