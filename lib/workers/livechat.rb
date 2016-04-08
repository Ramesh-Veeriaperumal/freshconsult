# Reseque Job to run livechat background jobs // Command : bundle exec rake resque:work QUEUE=livechat_queue VERBOSE=1
# POST /sites/busupdate , siteId :#{siteId}, payload :#{payload}

class Workers::Livechat
	extend Resque::AroundPerform
	require 'httparty'


	@queue = "livechat_queue"
	@subUrl = (Rails.env == "development") ? ":4000" : ""
	@url = "http://" + ChatConfig['communication_url'] + @subUrl

	class << self
	  include Livechat::Token

		def perform(args)
			args[:token] = get_token(args)
			send(args[:worker_method],args)
		end

		def get_token(params)
			token = ""
			token = livechat_partial_token(params[:siteId]) if params[:siteId]

		end
		
		def create_widget(args)
			response = HTTParty.post(@url+"/widgets/rescueCreate",:body => args)
		end

		def update_widget(args)
			response = HTTParty.post(@url+"/widgets/rescueUpdate",:body => args.to_json,:headers => { 'Content-Type' => 'application/json' })
		end

		def delete_widget(args)
			response = HTTParty.post(@url+"/widgets/delete",:body => args)
		end

		def update_site(args)
			response = HTTParty.post(@url+"/sites/rescueUpdate",:body => args) unless args[:siteId].blank?
		end

		def group_channel(args)
			response = HTTParty.post(@url+"/agent/groupChannel",:body => args)
		end

		def remove_group_from_routing(args)
			response = HTTParty.post(@url+"/sites/updaterouting",:body => args)
		end

		def disable_routing(args)
			response = HTTParty.post(@url+"/sites/disablerouting",:body => args)
		end
	end
end