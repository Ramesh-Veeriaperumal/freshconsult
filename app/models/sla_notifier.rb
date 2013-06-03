class SlaNotifier < ActionMailer::Base
	
    layout "email_font"

	def escalation(ticket, agents, params)
		subject       params[:subject]
		body          params[:email_body]
		recipients    agents.map { |agent| agent.email }
		from          ticket.account.default_friendly_email
		sent_on       Time.now 
		headers       "Reply-to" => "#{ticket.account.default_friendly_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
		content_type  "text/html"
	end

	def self.send_email(ticket, agents, n_type)
		# Sets portal timezone as current timezone while sending notifications
		Time.zone = self.account.time_zone 

		e_notification = ticket.account.email_notifications.find_by_notification_type(n_type)
		return unless e_notification.agent_notification?

		email_subject = Liquid::Template.parse(e_notification.agent_subject_template).render(
		                            'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
		email_body = Liquid::Template.parse(e_notification.formatted_agent_template).render(
		                            'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)

		# Resets the Thread.current[:account] to nil and resets current timezone
		#Account.reset_current_account 
		deliver_escalation(ticket, agents, 
		                                :email_body => email_body, :subject => email_subject)
  end
end
