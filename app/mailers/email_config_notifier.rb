class EmailConfigNotifier < ActionMailer::Base

  include EmailHelper
  helper EmailActionsHelper
  layout "email_font", :except => [:activation_instructions]

  def activation_instructions(email_config)
    headers = {
      :subject => I18n.t('mailer_notifier_subject.activation_instructions', portal_name: email_config.account.portal_name),
      :from    => email_config.random_noreply_email,
      :to      => email_config.reply_email,
      :sent_on => Time.now,
      "Auto-Submitted" => 'auto-generated',
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    headers.merge!(make_header(nil, nil, email_config.account_id, "Email Config Activation Instructions"))
    headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
    @activation_url = admin_register_email_url(email_config.activator_token, 
                        :host => email_config.account.host, :protocol => email_config.account.url_protocol)
    @email_config   = email_config
    mail(headers) do |part|
      part.html { render "activation_instructions.html" }
    end.deliver
    Rails.logger.info "Sending activation instructions for email_config - #{email_config.reply_email} - #{@activation_url.to_s}"
  end
  
  def test_email(email_config, send_to = nil)
    headers = {
      :subject => I18n.t('mailer_notifier_subject.test_email'),
      :from    => "#{AppConfig['app_name']} Test <#{Helpdesk::EMAIL[:default_requester_email]}>",
      :to      => send_to || email_config.reply_email,
      :sent_on => Time.now,
      "Reply-to" => "#{Helpdesk::EMAIL[:default_requester_email]}", 
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    headers.merge!(make_header(nil, nil, email_config.account_id, "Freshdesk Test Email"))
    headers.merge!({"X-FD-Email-Category" => email_config.category}) if email_config.category.present?
    @email_config = email_config
    mail(headers) do |part|
      part.html { render "test_email" }
    end.deliver
  end
  
  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias 
end
