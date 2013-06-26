#Contacts google api through google-api-client gem, gets calendar list for a user
#gets all subscribed holidays calendar. 
require 'google/api_client'
module GoogleClient

	FILE_PATH = "#{RAILS_ROOT}/config/google_api.yml"
	def self.included(base)
		config = YAML.load_file(FILE_PATH)
		oauth2 = config[Rails.env]["google_oauth2"]
		unless oauth2.nil?
			@@client_id = oauth2["consumer_token"]
			@@client_secret = oauth2["consumer_secret"]
			@@refresh_token = oauth2["refresh_token"]
			@@access_token = oauth2["access_token"]
			@@base_calendar_id = oauth2["base_calendar_id"]
			@@scope = oauth2["options"]["scope"] if oauth2["options"]
		end

	end

	def self.holidays_from_google(calendar_id)
      holidays_data = []

      client = establish_connection
      calendar = client.discovered_api('calendar', 'v3')

      result = client.execute(:api_method => calendar.events.list, 
        :parameters => {'calendarId' => calendar_id})

      begin
        response = result.data.to_hash["items"]
        if response.nil?
          Rails.logger.info "Error in fetching google calendar: #{result.data.to_hash.inspect}"
          return []
        end
        response.reject! { |item| item["start"]["date"].to_date.year != Date.today.year }
        holidays_data = response.collect { |item| [item["start"]["date"].to_date, item["summary"]] }.sort!
        holidays_data.collect! { |hd| [Date::ABBR_MONTHNAMES[hd[0].month].to_s + " " + hd[0].day.to_s,hd[1]] }
  	  rescue Exception => e
  		  Rails.logger.info "Unable to fetch holidays for #{calendar_id}, Trace: #{e.backtrace}"
  		  return holidays_data
  	  end

      return holidays_data
    end

    def self.calendars
    	calendars_list = []
    	client = establish_connection
      calendar = client.discovered_api('calendar', 'v3')
      result = client.execute(:api_method => calendar.calendar_list.list, 
        						:parameters => {'calendarId' => @@base_calendar_id})

      begin
        response = result.data.to_hash["items"]
        if response.nil?
          Rails.logger.info "Error in fetching google calendar: #{result.data.to_hash.inspect}"
          return []
        end
        #remove primary calendar from the list as we need not show it to user.
        response.reject! { |item| item["id"].include?(@@base_calendar_id) }
        calendars_list = response.collect { |res| [res["summary"],res["id"]]}
      rescue Exception => e
      	Rails.logger.info "Unable to fetch calendars Trace: #{e.backtrace.inspect}"
      	return calendars_list
      end
      calendars_list
    end

    def self.establish_connection
      client = Google::APIClient.new(:application_name => "Helpkit")
      client.authorization.client_id = @@client_id
      client.authorization.client_secret = @@client_secret
      client.authorization.scope = @@scope
      client.authorization.refresh_token = @@refresh_token
      client.authorization.access_token = @@access_token

      if client.authorization.refresh_token && client.authorization.expired?
        client.authorization.fetch_access_token!
        new_auth_token = client.authorization.access_token
        config = YAML.load_file(FILE_PATH)
        config[Rails.env]["google_oauth2"]["access_token"] = new_auth_token
        File.open(FILE_PATH, 'w'){|f| YAML.dump(config, f) }
        @@access_token = new_auth_token
      else
        client.authorization.access_token = @@access_token
      end
      client
    end

end