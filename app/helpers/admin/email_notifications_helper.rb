module Admin::EmailNotificationsHelper

	def get_requester_content(email_notification,language)
		content = email_notification.return_template(DynamicNotificationTemplate::CATEGORIES[:requester], language)
		return content.first unless content.blank?

	 	DynamicNotificationTemplate.new({
			:language => DynamicNotificationTemplate::LANGUAGE_MAP[language.to_sym], 
			:category => DynamicNotificationTemplate::CATEGORIES[:requester], 
			:email_notification_id => email_notification.id, 
			:active => true
			}) 
	end

	def get_agent_content(email_notification,language)
		content = email_notification.return_template(DynamicNotificationTemplate::CATEGORIES[:agent], language) 
		return content.first unless content.blank?

		DynamicNotificationTemplate.new({
			:language => DynamicNotificationTemplate::LANGUAGE_MAP[language.to_sym] , 
			:category => DynamicNotificationTemplate::CATEGORIES[:agent], 
			:email_notification_id => email_notification.id,
			:active => true
			}) 	
	end

	def get_agent_options
		current_account.agents.collect { |au| [au.user.id, au.user.name] }
	end

	ActionView::Base.default_form_builder = FormBuilders::FreshdeskBuilder
end		
