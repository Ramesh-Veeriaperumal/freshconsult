require 'sanitize'

module Integrations::SurveyMonkey
	
	def self.survey specific_include, ticket, user
		return nil unless enabled? ticket.account_id
		s_while = specific_include ? Survey::SPECIFIC_EMAIL_RESPONSE : Survey::ANY_EMAIL_RESPONSE
		installed_app = ticket.account.installed_applications.with_name('surveymonkey').first
		url = installed_app.configs[:inputs]['survey_link'] if installed_app
		if url.present?
			url ="#{url}?c=#{user.email}"
			send_while = installed_app.configs[:inputs]['send_while'].to_i 
		end
		return nil if url.blank? or send_while.blank? or (s_while!=send_while)
		{:link => url, :text => installed_app.configs[:inputs]['survey_text']}
	end

	def self.survey_for_notification notification_type, ticket
		return nil unless enabled? ticket.account_id
		installed_app = ticket.account.installed_applications.with_name('surveymonkey').first
		url = installed_app.configs[:inputs]['survey_link'] if installed_app
		if url.present? and ticket.responder
		 	url = "#{url}?c=#{ticket.responder.email}"
			send_while = installed_app.configs[:inputs]['send_while'].to_i
		end
		return nil if url.blank? or ticket.responder.blank? or send_while.blank? or
			(SurveyHandle::NOTIFICATION_VS_SEND_WHILE[notification_type]!=send_while and
			 notification_type!=Survey::PLACE_HOLDER)
		{:link => url, :text => installed_app.configs[:inputs]['survey_text']}
	end

	def self.placeholder_allowed? account
		return false unless enabled? account.id
		installed_app = account.installed_applications.with_name('surveymonkey').first
		url = installed_app.configs[:inputs]['survey_link'] if installed_app
		url.present?
	end

	def self.survey_html ticket
		ActionController::Base.helpers.render({
			:partial => "app/views/helpdesk/ticket_notifier/satisfaction_survey.html.erb",
			:locals => {:survey_handle => nil, :in_placeholder => true,
				:surveymonkey_survey => survey_for_notification(Survey::PLACE_HOLDER, ticket)}})
	end

	def self.enabled? account_id
	    MemcacheKeys.fetch("surveymonkey_#{account_id}") { 
	    	account ||= Account.find(account_id)
	    	if account
		    	ret_value = !!account.installed_applications.with_name('surveymonkey').first
		    else
		    	ret_value = false
		    end
	    }	
	end

	def self.show_surveymonkey_checkbox? account
		return false unless enabled? account.id
		installed_app = account.installed_applications.with_name('surveymonkey').first
		send_while = installed_app.configs[:inputs]['send_while'].to_i if installed_app
		return true if send_while and send_while == Survey::SPECIFIC_EMAIL_RESPONSE
		false
	end

	def self.sanitize_survey_text installed_app
		installed_app.configs[:inputs]['survey_text'] = Sanitize.clean(installed_app.configs[:inputs]['survey_text'],
			Sanitize::Config::BASIC)
	end

	def self.delete_cached_status installed_app
		MemcacheKeys.delete_from_cache "surveymonkey_#{installed_app.account_id}" if installed_app
	end	

end