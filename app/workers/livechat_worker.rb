
class LivechatWorkerException <  Exception
	def initialize(message, action)
		# Call the parent's constructor to set the message
		super(message)

		# Store the action in an instance variable
		@action = action
	end
end


class LivechatWorker < BaseWorker
	require 'httparty'
	include Livechat::Token

	SUBURL = (Rails.env == "development") ? ":4000" : ""
	URL = "http://" + ChatConfig['communication_url'] + SUBURL

  sidekiq_options :queue => :livechat_worker, :retry => 0, :failures => :exhausted

	def perform(args)
		worker_method_name = args["worker_method"]
		args["token"] 					= get_token(args, worker_method_name)
		# added account and current user params to the arguments.
		# current_user_id is being used in live chat privilege check.
		args["account_id"] 			 = Account.current.id
		# note User.current.nil? - not needed as get_token will raise excp if User.current is nil
		# TODO - get this deleted in code review with Thanashyam
		args["userId"]           = User.current.id unless User.current.nil?
		args['siteId'] 					 = Account.current.chat_setting.site_id
		args['appId'] 					 = ChatConfig['app_id']
		safe_send(worker_method_name, args)
	end

	def get_token(params, worker_method_name)
		site_id = Account.current.chat_setting.site_id
		if User.current.nil? || site_id.nil?
			exception_obj = LivechatWorkerException.new(
				"Unexpected User.current is nil : #{User.current.nil? ?  'nil' : User.current.id } or site_id is nil: #{site_id.nil? ?  'nil' : site_id }",
				worker_method_name)
			NewRelic::Agent.notice_error(exception_obj,
                                   {:description => "error occured while running worker #{worker_method_name} on behalf of user #{ @user.inspect }   in account: #{ Account.current.nil? ? "nil" :  Account.current.id}"})
			raise exception_obj
		else
			return livechat_token(site_id, User.current.id,
                            User.current.privilege?(:admin_tasks))
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
