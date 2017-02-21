class SecurityEmailNotification < ActionMailer::Base
  layout "email_font"
  include EmailHelper

  def agent_alert_mail(model, subject, changed_attributes)
    begin
      # sending this email via account's primary email config so that if the customer wants this emails 
      # to be sent via custom mail server, simply switching the primary email config will do
      email_config = Account.current.primary_email_config
      configure_email_config email_config
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
      headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
      @changes = changed_attributes
      @time = Time.zone.now.strftime('%B %e at %l:%M %p %Z')
      @model = model
      @account = Account.current

      mail(headers) do | part|
        part.text { render "agent_alert_mail.text.plain.erb" }
        part.html { render "agent_alert_mail.text.html.erb" }
      end.deliver
    ensure
      remove_email_config
    end

  end
  def agent_email_change(model,to, subject, changed_attributes,doer)
    begin
      # sending this email via account's primary email config so that if the customer wants this emails
      # to be sent via custom mail server, simply switching the primary email config will do
      email_config = Account.current.primary_email_config
      configure_email_config email_config
      Time.zone = model.time_zone
      agent_headers = {
        :to    => to,
        :from  => Account.current.default_friendly_email,
        :subject => subject,
        :sent_on => Time.now,
        "Reply-to" => "",
        "Auto-Submitted" => "auto-generated",
        "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
      }
      admin_headers = {
        :to    => doer.email,
        :from  => Account.current.default_friendly_email,
        :subject => subject,
        :sent_on => Time.now,
        "Reply-to" => "",
        "Auto-Submitted" => "auto-generated",
        "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
      }

      account_id = -1
      account_id = Account.current.id if Account.current
      agent_headers.merge!(make_header(nil, nil, account_id, "Agent Email Change"))
      agent_headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
      admin_headers.merge!(make_header(nil, nil, account_id, "Agent Email Change"))
      admin_headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
      @changes = changed_attributes
      @time = Time.zone.now.strftime('%B %e at %l:%M %p %Z')
      @model = model
      @account = Account.current
      @doer =doer
      mail(admin_headers) do | part|
        part.text { render "admin_alert_email_change.text.html.erb" }
        part.html { render "admin_alert_email_change.text.html.erb" }
      end.deliver
      mail(agent_headers) do | part|
        part.text { render "agent_email_change.text.plain.erb" }
        part.html { render "agent_email_change.text.html.erb" }
      end.deliver
    ensure
      remove_email_config
    end

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
