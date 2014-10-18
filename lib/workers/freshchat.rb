# Reseque Job to run freshchat background jobs // Command : bundle exec rake resque:work QUEUE=freshchatQueue VERBOSE=1
# POST /sites/busupdate , siteId :#{siteId}, payload :#{payload}

class Workers::Freshchat
	extend Resque::AroundPerform
	require 'httparty'
	require "openssl"
	require 'base64'
	@queue = "freshchat_queue"
	@subUrl = (Rails.env == "development") ? ":4000" : ""
	@url = "http://" + ChatConfig['communication_url'][Rails.env] + @subUrl

	def self.perform(args)
		token = Digest::SHA512.hexdigest("#{ChatConfig['secret_key'][Rails.env]}::#{args[:siteId]}")
		args["token"] = token
		send(args[:worker_method],args)
	end

	def self.create_widget(args)
		response = HTTParty.post(@url+"/widgets/create",:body => args)
	end

	def self.update_widget(args)
		response = HTTParty.post(@url+"/widgets/update",:body => args)
	end

	def self.destroy_widget(args)
		response = HTTParty.post(@url+"/widgets/destroy",:body => args)
	end

end