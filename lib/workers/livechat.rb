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

			if params[:user_id] && params[:siteId]
				token = livechat_token(params[:siteId], params[:user_id])
			elsif params[:siteId]
				token = livechat_partial_token(:siteId => params[:siteId])
			elsif params[:user_id]
				token = livechat_partial_token(:userId => params[:user_id])
			end
			return token
		end
		
		def create_widget(args)
			response = HTTParty.post(@url+"/widgets/create",:body => args)
		end

		def update_widget(args)
			response = HTTParty.post(@url+"/widgets/update",:body => args)
		end

		def delete_widget(args)
			response = HTTParty.post(@url+"/widgets/delete",:body => args)
		end

		def update_site(args)
			response = HTTParty.post(@url+"/sites/update",:body => args)
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