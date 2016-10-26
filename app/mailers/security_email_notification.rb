class SecurityEmailNotification < ActionMailer::Base
  layout "email_font"
  include EmailHelper

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

    account_id = -1
    account_id = Account.current.id if Account.current

    headers.merge!(make_header(nil, nil, account_id, "Agent Alert Email"))
    @changes = changed_attributes
    @time = Time.zone.now.strftime('%B %e at %l:%M %p %Z')
    @model = model
    @account = Account.current

    mail(headers) do | part|
      part.text { render "agent_alert_mail.text.plain.erb" }
      part.html { render "agent_alert_mail.text.html.erb" }
    end.deliver
  end

  def admin_alert_mail(model, subject, body_message_file, changed_attributes, doer)
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

    headers.merge!(make_header(nil, nil, Account.current.id, "Admin Alert Email"))
    @changes = changed_attributes
    @time = Time.zone.now.strftime('%B %e at %l:%M %p %Z')
    @model = model
    @doer = doer
    @account = Account.current

    mail(headers) do | part|
      part.text { render "#{body_message_file}.text.plain.erb" }
      part.html { render "#{body_message_file}.text.html.erb" }
    end.deliver
  end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
    
end
