class SlaNotifier < ActionMailer::Base
	
	def escalation(ticket, agents, params)
		subject       params[:subject]
		body          params[:email_body].html_safe
		recipients    agents.map { |agent| agent.email }
		from          ticket.account.default_friendly_email
		sent_on       Time.now 
		headers       "Reply-to" => "#{ticket.account.default_friendly_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
		content_type  "multipart/mixed"
		part :content_type => "multipart/alternative" do |alt|
			alt.part "text/plain" do |plain|
        		plain.body  render_message("escalation.text.plain.erb", :body => Helpdesk::HTMLSanitizer.plain(params[:email_body]))
      		end
      		alt.part "text/html" do |html|
	        	html.body   render_message("escalation.text.html.erb", :body => params[:email_body])
	      	end
		end
	end

	def self.send_email(ticket, agents, n_type)
		time_zone = Time.zone # save current time_zone
		# Sets portal timezone as current timezone while sending notifications		
		Time.zone = ticket.account.time_zone 
		begin
			e_notification = ticket.account.email_notifications.find_by_notification_type(n_type)
			return unless e_notification.agent_notification?

			email_subject = Liquid::Template.parse(e_notification.agent_subject_template).render(
			                            'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
			email_body = Liquid::Template.parse(e_notification.formatted_agent_template).render(
			                            'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name)
		ensure
			Time.zone = time_zone
		end

		deliver_escalation(ticket, agents, 
		                                :email_body => email_body, :subject => email_subject)
  end
end
