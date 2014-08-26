# Reseque Job to run freshchat background jobs // Command : bundle exec rake resque:work QUEUE=freshchatQueue VERBOSE=1
# POST /sites/busupdate , siteId :#{siteId}, payload :#{payload}

class Freshchat::BusinessCalUpdate
	extend Resque::AroundPerform
	require 'httparty'
	require "openssl"
	require 'base64'
	@queue = "freshchatQueue"
	@url = "http://" + ChatConfig['communication_url'][Rails.env] + ":4000/sites/calendarupdate"

	def self.perform(args)
		token = Digest::SHA512.hexdigest("#{ChatConfig['secret_key'][Rails.env]}::#{args[:display_id]}")
		body = {"siteId" => args[:display_id],"token" => token, "business_calendar" => args[:calendarData], "proactive_chat" => args[:proactive_chat] || nil, "proactive_time" => args[:proactive_time] || nil}
		response = HTTParty.post(@url,:body => body)
	end
end