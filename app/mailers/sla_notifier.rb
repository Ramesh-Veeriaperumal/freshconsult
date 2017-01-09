class SlaNotifier < ActionMailer::Base
	
  include Helpdesk::NotifierFormattingMethods
  include EmailHelper
	layout "email_font"

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
    Time.use_zone(ticket.account.time_zone) {
      e_notification = ticket.account.email_notifications.find_by_notification_type(n_type)
      return unless e_notification.agent_notification?

      agents_arr = ticket.account.users.technicians.visible
                         .find(:all, :conditions => ["id in (?)", agent_ids])

      agents_arr.each do |agent|
        i_notif = (ticket.internal_agent_id == agent.id)
        email_subject, email_body = get_email_content(e_notification, agent, ticket, i_notif)
        trigger_escalation(ticket, agent, n_type, 
                          { :email_body => email_body,  :subject => email_subject })
      end 
    }
  end

  def trigger_escalation(ticket, agent, n_type, params)
    # Setting the headers to nil in order to allow the replacement of header attributes. 
    # This avoids duplication of attributes while called multiple times in loop.
    mail.header = nil
    @ticket = ticket
    begin
      configure_email_config ticket.reply_email_config if ticket.account.features?(:all_notify_by_custom_server)
      headers = {
        :subject                   => params[:subject],
        :to                        => agent.email,
        :from                      => ticket.account.default_friendly_email,
        :sent_on                   => Time.now,
        "Reply-to"                 => "#{ticket.account.default_friendly_email}",
        "Auto-Submitted"           => "auto-generated", 
        "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
      }
      headers.merge!(make_header(ticket.display_id, nil, ticket.account_id, n_type))
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
    ensure
      remove_email_config
    end
  end

  def get_email_content(e_notification, agent, ticket, i_notif=false)
    subject_template, message_template = i_notif ? e_notification.get_internal_agent_template(agent) : e_notification.get_agent_template(agent)
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
