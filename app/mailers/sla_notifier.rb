class SlaNotifier < ActionMailer::Base
	
  include Helpdesk::NotifierFormattingMethods

	layout "email_font"

	def escalation(ticket, agent, n_type, params)
		@ticket = ticket
		headers = {
			:subject                   => params[:subject],
			:to                        => agent.email,
			:from                      => ticket.account.default_friendly_email,
			:sent_on                   => Time.now,
			"Reply-to"                 => "#{ticket.account.default_friendly_email}",
			"Auto-Submitted"           => "auto-generated", 
			"X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply",
	        "Account-Id" =>  ticket.account_id,
	        "Ticket-Id"  =>  ticket.display_id,
	        "Type"  =>  n_type
		}
		headers.merge!({"X-FD-Email-Category" => ticket.reply_email_config.category}) if ticket.reply_email_config.category.present?
	    references = generate_email_references(ticket)
        headers["References"] = references unless references.blank?
		mail(headers) do |part|
			part.text do
				@body = Helpdesk::HTMLSanitizer.plain(params[:email_body])
				render "escalation.text.plain" 
			end
			part.html do
				@body = params[:email_body]
                @account = ticket.account
				render "escalation.text.html" 
			end
		end.deliver
	end

	def self.send_email(ticket, agents, n_type)
		time_zone = Time.zone # save current time_zone
		# Sets portal timezone as current timezone while sending notifications		
		Time.zone = ticket.account.time_zone 
		e_notification = ticket.account.email_notifications.find_by_notification_type(n_type)
		return unless e_notification.agent_notification?
		agents.each do |agent|
			begin
				subject_template, message_template = e_notification.get_agent_template(agent)
				email_subject = Liquid::Template.parse(subject_template).render(
				                            'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
				email_body = Liquid::Template.parse(message_template).render(
				                            'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
			ensure
				Time.zone = time_zone
			end
			escalation(ticket, agent, n_type,
			                                :email_body => email_body, :subject => email_subject)
		end	
  end

  def agent_escalation(ticket, agent, n_type)
    e_notification = ticket.account.email_notifications.find_by_notification_type(n_type)
    return unless e_notification.agent_notification
    agent.make_current
    email_subject, email_body = get_email_content(e_notification, agent, ticket)
    trigger_escalation(ticket, agent, n_type, 
                      { :email_body => email_body, :subject => email_subject })
  ensure
    User.reset_current
  end

  def group_escalation(ticket, agent_ids, n_type)
    time_zone = Time.zone # save current time_zone
    # Sets portal timezone as current timezone while sending notifications    
    Time.zone = ticket.account.time_zone 
    e_notification = ticket.account.email_notifications.find_by_notification_type(n_type)
    return unless e_notification.agent_notification?

    agents_arr = ticket.account.users.technicians.visible
                       .find(:all, :conditions => ["id in (?)", agent_ids])

    agents_arr.each do |agent|
      begin
        email_subject, email_body = get_email_content(e_notification, agent, ticket)
      ensure
        Time.zone = time_zone
      end
      trigger_escalation(ticket, agent, n_type, 
                        { :email_body => email_body,  :subject => email_subject })
    end 
  end

  def trigger_escalation(ticket, agent, n_type, params)
    @ticket = ticket
    headers = {
      :subject                   => params[:subject],
      :to                        => agent.email,
      :from                      => ticket.account.default_friendly_email,
      :sent_on                   => Time.now,
      "Reply-to"                 => "#{ticket.account.default_friendly_email}",
      "Auto-Submitted"           => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply",
          "Account-Id" =>  ticket.account_id,
          "Ticket-Id"  =>  ticket.display_id,
          "Type"  =>  n_type
    }
    headers.merge!({"X-FD-Email-Category" => ticket.reply_email_config.category}) if ticket.reply_email_config.category.present?
      references = generate_email_references(ticket)
        headers["References"] = references unless references.blank?
    mail(headers) do |part|
      part.text do
        @body = Helpdesk::HTMLSanitizer.plain(params[:email_body])
        render "escalation.text.plain" 
      end
      part.html do
        @body = params[:email_body]
        @account = ticket.account
        render "escalation.text.html" 
      end
    end.deliver
  end

  def get_email_content e_notification, agent, ticket
    subject_template, message_template = e_notification.get_agent_template(agent)
    email_subject = Liquid::Template.parse(subject_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
    email_body = Liquid::Template.parse(message_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
    [email_subject, email_body]
  end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end
