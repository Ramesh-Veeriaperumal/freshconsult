
class LivechatWorker < BaseWorker
	require 'httparty'
	include Livechat::Token

	SUBURL = (Rails.env == "development") ? ":4000" : ""
	URL = "http://" + ChatConfig['communication_url'] + SUBURL

  sidekiq_options :queue => :livechat_worker, :retry => 0, :backtrace => true, :failures => :exhausted

	def perform(args)
		args["token"] 					= get_token(args)
		# added account and current user params to the arguments.
		# current_user_id is being used in live chat privilege check.
		args["account_id"] 			 = Account.current.id
		args["userId"]           = User.current.id unless User.current.nil?
		args['siteId'] 					 = Account.current.chat_setting.site_id
		args['appId'] 					 = ChatConfig['app_id']
		send(args["worker_method"],args)
	end

	def get_token(params)
		site_id = Account.current.chat_setting.site_id
		if User.current && User.current.id
			return livechat_token(site_id, User.current.id)
		else
			return livechat_partial_token(site_id)
		end
	end

	def create_widget(args)
		response = HTTParty.post(URL+"/widgets",:body => args)
	end

	def livechat_sync(args)
		Livechat::Sync.new.sync_data_to_livechat(args['siteId'])
	end

	def update_widget(args)
		response = HTTParty.put(URL+"/widgets/#{args['widget_id']}",:body => args) unless args["widget_id"].blank?
	end

	def delete_widget(args)
		response = HTTParty.delete(URL+"/widgets/#{args['widget_id']}"+"?"+args.to_query) unless args["widget_id"].blank?
	end

	def update_site(args)
		response = HTTParty.put(URL+"/sites/#{args['siteId']}",:body => args) unless args["siteId"].blank?
	end

	def group_channel(args)
		response = HTTParty.post(URL+"/agents/#{args['agent_id']}/groupChannel",:body => args)
	end

	def disable_routing(args)
		response = HTTParty.put(URL+"/sites/#{args['siteId']}/disableRouting",:body => args)
	end

	def create_group(args)
		response = HTTParty.post(URL+"/groups/createOrUpdate",:body => args)
	end

	def delete_group(args)
		response = HTTParty.delete(URL+"/groups/#{args['group_id']}"+"?"+args.to_query)
	end

	def enable_prirvilege_check(args)
		response = HTTParty.post(URL+"/sites/enablePrivilegeCheck",:body => args)
	end

	def create_agent(args)
		response = HTTParty.post(URL+"/agents/createOrUpdate",:body => args)
	end

	def create_role(args)
		response = HTTParty.post(URL+"/roles/createOrUpdate",:body => args)
	end

	def delete_role(args)
		response = HTTParty.delete(URL+"/roles/#{args['role_id']}"+"?"+args.to_query)
	end

end
