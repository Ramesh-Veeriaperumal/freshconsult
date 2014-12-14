class SlaNotifier < ActionMailer::Base
	
	layout "email_font"

	def escalation(ticket, agent, params)
		headers = {
			:subject                   => params[:subject],
			:to                        => agent.email,
			:from                      => ticket.account.default_friendly_email,
			:sent_on                   => Time.now,
			"Reply-to"                 => "#{ticket.account.default_friendly_email}",
			"Auto-Submitted"           => "auto-generated", 
			"X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
		}
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
				agent_template = e_notification.get_agent_template(agent)
				email_subject = Liquid::Template.parse(agent_template.first).render(
				                            'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
				email_body = Liquid::Template.parse(agent_template.last).render(
				                            'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
			ensure
				Time.zone = time_zone
			end
			escalation(ticket, agent, 
			                                :email_body => email_body, :subject => email_subject)
		end	
  end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
end
