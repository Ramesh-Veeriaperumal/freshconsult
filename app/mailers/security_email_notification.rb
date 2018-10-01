class SecurityEmailNotification < ActionMailer::Base
  layout "email_font"
  include EmailHelper

  AUTO_REPLY_EMAIL_HEADERS = {
    "Reply-to" => "",
    "Auto-Submitted" => "auto-generated", 
    "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
  }.freeze

  # DEPRECATED Can be removed in an upcoming release
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
        :subject => I18n.t('mailer_notifier_subject.agent_details_updated',
                            changed_attributes: changed_attributes.to_sentence,
                            account_name: model.account.name),
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

  def agent_update_alert(model, changed_attributes)
    begin
      # sending this email via account's primary email config so that if the customer wants this emails 
      # to be sent via custom mail server, simply switching the primary email config will do
      email_config = Account.current.primary_email_config
      configure_email_config email_config
      Time.zone = model.time_zone

      headers = construct_headers({
        to: model.email, 
        from: Account.current.default_friendly_email,
        subject: I18n.t('mailer_notifier_subject.agent_details_updated',
                            changed_attributes: changed_attributes.to_sentence,
                            account_name: model.account.name),
        sent_on: Time.now 
      }, Account.current.id, "Agent Alert Email")
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

  # DEPRECATED Can be removed in an upcoming release
  def agent_email_change(model, to, subject, changed_attributes, doer, mail_template)
    begin
      # sending this email via account's primary email config so that if the customer wants this emails
      # to be sent via custom mail server, simply switching the primary email config will do
    return if doer.blank? or to.blank?
      email_config = Account.current.primary_email_config
      configure_email_config email_config
      Time.zone = model.time_zone
      headers = {
        :to    => to,
        :from  => Account.current.default_friendly_email,
        :subject => I18n.t('mailer_notifier_subject.agent_email_changed',
                      portal_name: model.account.helpdesk_name),
        :sent_on => Time.now,
        "Reply-to" => "",
        "Auto-Submitted" => "auto-generated",
        "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
      }
      account_id = Account.current.present? ? Account.current.id : -1
      headers.merge!(make_header(nil, nil, account_id, "Agent Email Change"))
      headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
      @changes = changed_attributes
      @time = Time.zone.now.strftime('%B %e at %l:%M %p %Z')
      @model = model
      @account = Account.current
      @doer = doer

      mail(headers) do | part|
        part.text { render "#{mail_template}.text.plain.erb" }
        part.html { render "#{mail_template}.text.html.erb" }
      end.deliver
    ensure
      remove_email_config
    end
  end

  def agent_email_change_alert(model, to, changed_attributes, doer, mail_template)
    begin
      # sending this email via account's primary email config so that if the customer wants this emails
      # to be sent via custom mail server, simply switching the primary email config will do
    return if doer.blank? or to.blank?
      email_config = Account.current.primary_email_config
      configure_email_config email_config
      Time.zone = model.time_zone

      headers = construct_headers({
        to: to, 
        from: Account.current.default_friendly_email,
        subject: I18n.t('mailer_notifier_subject.agent_email_changed',
                      portal_name: model.account.helpdesk_name),
        sent_on: Time.now 
      }, Account.current.id, "Agent Email Change")
      headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
      @changes = changed_attributes
      @time = Time.zone.now.strftime('%B %e at %l:%M %p %Z')
      @model = model
      @account = Account.current
      @doer = doer

      mail(headers) do | part|
        part.text { render "#{mail_template}.text.plain.erb" }
        part.html { render "#{mail_template}.text.html.erb" }
      end.deliver
    ensure
      remove_email_config
    end
  end

  def admin_alert_mail(model, subject, body_message_file, changed_attributes, doer)
    @account = Account.current
    Time.zone = @account.time_zone
    headers = construct_headers({
      to: Account.current.notification_emails, 
      from: AppConfig['from_email'],
      subject: subject.is_a?(Hash) ? I18n.t(subject[:key], subject[:locals]) : subject,
      sent_on: Time.now 
    }, @account.id, "Admin Alert Email")

    @changes = changed_attributes
    @time = Time.zone.now.strftime('%B %e at %l:%M %p %Z')
    @model = model
    @doer = doer

    mail(headers) do | part|
      part.text { render "#{body_message_file}.text.plain.erb" }
      part.html { render "#{body_message_file}.text.html.erb" }
    end.deliver
  end

  private

  def construct_headers(params, account_id, mail_type)
    headers = AUTO_REPLY_EMAIL_HEADERS.dup
    headers.merge(params)
           .merge(make_header(nil, nil, account_id, mail_type))
  end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias
    
end
