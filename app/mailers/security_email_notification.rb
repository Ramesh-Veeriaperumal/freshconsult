class SecurityEmailNotification < ActionMailer::Base

  def agent_alert_mail(model, subject, changed_attributes)
    Time.zone = model.time_zone
    headers = {
      :to    => model.email,
      :from  => Account.current.default_friendly_email,
      :subject => subject,
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    @model = model, 
    @changes = changed_attributes, 
    @time = Time.zone.now.strftime('%B %e at %l:%M %p %Z')

    mail(headers) do | part|
      part.html { render "agent_alert_mail.html" }
      part.text { render "agent_alert_mail.text" }
    end.deliver
  end

  def admin_alert_mail(model, subject, body_message_file, changed_attributes)
    Time.zone = Account.current.time_zone
    headers = {
      :to    => Account.current.notification_emails,
      :from  => AppConfig['from_email'],
      :subject => subject,
      :sent_on => Time.now,
      "Reply-to" => "",
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }

    @model = model, 
    @changes = changed_attributes, 
    @time = Time.zone.now.strftime('%B %e at %l:%M %p %Z')

    mail(headers) do | part|
      part.html { render "#{body_message_file}.text.html.erb" }
      part.text { render "#{body_message_file}.text.plain.erb" }
    end.deliver
  end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
    
end
