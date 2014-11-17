module Helpdesk::Email::ParseEmailData
	include ParserUtil
	include ActionView::Helpers::TagHelper
	include ActionView::Helpers::TextHelper
	include ActionView::Helpers::UrlHelper

	attr_accessor :reply_to_email, :recipients

	def email_metadata
		{
			:to => to_email || parse_to_email, 
			:from => parse_from_email,
			:cc => get_email_array(params["Cc"]),
			:subject => params["subject"],
			:email_config => get_email_config
		}
	end

	def additional_email_data
		{
			:attachments => params["attachment-count"],
			:attached_items => fetch_all_attachments,
			:content_ids => get_content_ids,
			:description_html => description_html		
		}
	end

	def parse_ticket_metadata
		{
			:to_emails => get_email_array(params["To"]), 
			:text => params["body-plain"],
			:html => params["body-html"],
			:stripped_html => params["stripped-html"] || params["body-html"],
			:stripped_text => params["stripped-text"] || params["body-plain"],
			:headers => params["message-headers"],
			:message_id => params["Message-Id"],
			:references => params["References"],
			:in_reply_to => params["In-Reply-To"]
		}
	end

	def description_html
		Helpdesk::HTMLSanitizer.clean(params["body-html"]) || params["body-plain"]
	end

	def parse_from_email
		parse_reply_to_email if reply_to_feature and params["Reply-To"].present?

		#Assigns email of reply_to if feature is present or gets it from params[:from]
		#Will fail if there is spaces and no key after reply_to or has a garbage string
		f_email = reply_to_email || parse_email_with_domain(params[:from])

		#Ticket will be created for no_reply if there is no other reply_to
		f_email = reply_to_email if valid_from_email?(f_email)
		return f_email unless f_email[:email].blank?
	end

	def additional_reply_to_emails
		get_email_array(params["Reply-To"])[1..-1]
	end

	def reply_to_feature
		@acc_reply_to_feature ||= account.features?(:reply_to_based_tickets)
	end

	def parse_reply_to_email
		self.reply_to_email = parse_email_with_domain(params["Reply-To"])
	end

	def valid_from_email? f_email
	  (f_email[:email] =~ /(noreply)|(no-reply)/i or f_email[:email].blank?) and !reply_to_feature and parse_reply_to_email[:email].present?
	end

	def parse_to_email
		parse_email_with_domain(parse_recipients.first)
	end

	def parse_recipients
		self.recipients ||= params[:recipient].split(',')
	end

	def check_for_kbase_email
		recipients.include?(kbase_email) or (common_email_data[:cc] && common_email_data[:cc].include?(kbase_email))
	end

	def fetch_all_attachments
		params.select { |k,v| k =~ /attachment-[0-9]+/} || {}
	end

	def support_email_from_recipients
		recipients.each do |email|
			to_email = account.email_configs.find_by_to_email(email)
			return parse_email_with_domain(email) if to_email.present?
		end
		parse_email_with_domain(recipients.first)
	end

	# def parse_to_emails
	# 	to = get_emails(params[:to])
	# 	to.collect{|parsed_email| "#{parsed_email[:name]} <#{parsed_email[:email].downcase.strip}>"}
	# end

	def get_content_ids
		content_ids = {}
		if params["content-id-map"]
	    parse_content_ids.each do |content_id|
	      split_content_id = content_id.split(":")
	      content_ids[split_content_id[1]] = split_content_id[0]
	    end
	  end
	  content_ids
	end

	def parse_content_ids
		params["content-id-map"].tr("{}\\<>\" ","").split(",") 
	end

	def body_html_with_formatting(body,email_cmds_regex)
	  body = body.gsub(email_cmds_regex,'<notextile>\0</notextile>')
	  body_html = auto_link(body) { |text| truncate(text, 100) }
	  textilized = RedCloth.new(body_html.gsub(/\n/, '<br />'), [ :hard_breaks ])
	  textilized.hard_breaks = true if textilized.respond_to?("hard_breaks=")
	  white_list(textilized.to_html)
	end

	def get_email_config
		account.email_configs.find_by_to_email(to_email[:email])
	end

	def get_user from_email, email_config, email_body
		self.user = account.all_users.find_by_email(from_email[:email])
	    unless user
	      self.user = account.contacts.new
	      signup_status = user.signup!({:user => user_params(from_email), :email_config => email_config},
	      															get_portal(email_config))
	      detect_user_language(signup_status, email_body)
	    end
	    user.make_current
	  user
	end

	def user_params from_email
		{
			:email => from_email[:email], #user_email_changed
			:name => from_email[:name],
			:helpdesk_agent => false,
			:language => set_language,
			:created_from_email => true
		}
	end

	def set_language
		(account.features?(:dynamic_content)) ? nil : account.language
	end

	def detect_user_language signup_status, email_body
		args = [user, text_for_detection(email_body)]  
		Delayed::Job.enqueue(Delayed::PerformableMethod.new(Helpdesk::DetectUserLanguage, :set_user_language!, args), nil, 1.minutes.from_now) if user.language.nil? and signup_status
	end

	def text_for_detection email_body
	  text = email_body[0..100]
	  text.gsub("\n","").squeeze(" ").split(" ")[0..5].join(" ")
	end

	def get_portal email_config
		(email_config && email_config.product) ? email_config.product.portal : account.main_portal
	end

end