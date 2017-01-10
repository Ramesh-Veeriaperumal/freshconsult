namespace :email_events do

  MAILGUN_API_KEY = YAML.load_file(File.join(Rails.root, 'config', 'mailgun.yml'))[Rails.env]['api_key']

  desc "Tracking events of email in mailgun"
  task :mailgun, [:domain] => [:environment] do |t, args|
    include Redis::OthersRedis
    include Redis::RedisKeys

    1.step do |i|
      initial_start = ((i == 1) ? true : false)
      track_mailgun_events(args['domain'], initial_start)
      sleep(30)
    end
  end

end

def track_mailgun_events(domain, initial_start)
  key = MAILGUN_EVENT_LAST_SYNC % {:domain => domain }
  stored_value = get_others_redis_key(key)

  last_synced_url, last_synced_time = fetch_last_synced_data(stored_value, initial_start)
  url = "@api.mailgun.net/v3/#{domain}/events"

  event_url = last_synced_url ? last_synced_url : url
  response = JSON.parse(fetch_api(event_url, last_synced_time))

  while response["items"].present? do
    process_items(response["items"])
    event_url = response["paging"]["next"].gsub("https://", "@")
    set_others_redis_key(key, "#{event_url}:#{response['items'].last['timestamp']}", nil)
    response = JSON.parse(fetch_api(event_url, false))
  end
end

def fetch_last_synced_data(stored_value, initial_start)
  if stored_value.present?
    time = Time.at(stored_value.split(':').last.to_i)
    last_synced_time = (initial_start || (Time.now - time > 15.minutes)) ? time : nil
    last_synced_url = stored_value.split(':').first if (Time.now - time < 15.minutes)
  else
    last_synced_time = (DateTime.now - 1.hour)
  end
  return last_synced_url, last_synced_time
end

def fetch_api(event_url, last_sync)
  if last_sync
    response = RestClient.get("https://api:#{MAILGUN_API_KEY}"\
    "#{event_url}", :params => { :'begin' => last_sync.to_datetime.strftime("%a, %d %b %Y %H:%M:%S %z"), 
      :'ascending' => 'yes', :'limit' => 100, :'pretty' => 'yes'})
  else
    response = RestClient.get("https://api:#{MAILGUN_API_KEY}"\
      "#{event_url}")
  end
  mailgun_events_logger.info "Response code: #{response.code}" unless response.code == 200
  response
rescue Exception => e
  mailgun_events_logger.info "Exception while fetching events from mailgun. #{e.message} - #{e.backtrace}"
  "{}"
end

def process_items(items)
  items.each do |event|
    if (event["user-variables"].present? && event["user-variables"]["message_id"].present? && event["user-variables"]["message_id"].is_a?(Array))
      custom_messages = event["user-variables"]["message_id"]
      custom_messages.each do |msg|
        log_events(event, msg)
      end 
    else
      custom_message = event["user-variables"].present? ? event["user-variables"]["message_id"] : nil
      log_events(event, custom_message)
    end
  end
end

def log_events(event_obj, msg)
  custom_variables = ActionMailer::Base.decrypt_to_custom_variables(msg) if msg.present?
  mailgun_events_logger.info "Event type: #{event_obj["event"]}\nMessage-Id: "\
         "#{event_obj["message"]["headers"]["message-id"]}\nSubject: #{event_obj["message"]["headers"]["subject"]}\n"\
          "Recipient : #{event_obj["recipient"]}\nCustom variables: #{custom_variables.inspect}\n"\
           "Timestamp: #{event_obj["timestamp"]}\nFrom: #{event_obj["message"]["headers"]["from"]}\n"
end

def mailgun_events_logger
  @mailgun_events_logger ||= CustomLogger.new("#{Rails.root}/log/mailgun_events.log")
end