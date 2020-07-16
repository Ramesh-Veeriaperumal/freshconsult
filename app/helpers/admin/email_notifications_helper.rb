module Admin::EmailNotificationsHelper
	include Utils::RequesterPrivilege # methods used in erb files, don't remove

	def get_requester_content(email_notification,language)
		content = define_template(email_notification,language,:requester)
		return content.first unless content.blank?

	 	DynamicNotificationTemplate.new({
			:language => DynamicNotificationTemplate::LANGUAGE_MAP[language.to_sym], 
			:category => DynamicNotificationTemplate::CATEGORIES[:requester], 
			:email_notification_id => email_notification.id, 
			:active => true
			}) 
	end

	def get_agent_content(email_notification,language)
		content = define_template(email_notification,language,:agent)
		return content.first unless content.blank?

		DynamicNotificationTemplate.new({
			:language => DynamicNotificationTemplate::LANGUAGE_MAP[language.to_sym] , 
			:category => DynamicNotificationTemplate::CATEGORIES[:agent], 
			:email_notification_id => email_notification.id,
			:active => true
			}) 	
	end

	def agent_options
		user_ids = current_account.agents.pluck(:user_id)
		current_account.users.select("id, name").find_all_by_id(user_ids).collect { |au| [au.id, au.name] }
	end

	private

		def define_template(email_notification,language,user)
			email_notification.return_template(DynamicNotificationTemplate::CATEGORIES[user], language) 
		end

	ActionView::Base.default_form_builder = FormBuilders::FreshdeskBuilder
end		
