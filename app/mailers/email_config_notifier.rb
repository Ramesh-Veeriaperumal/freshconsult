class EmailConfigNotifier < ActionMailer::Base
  
  include EmailHelper  
  layout "email_font", :except => [:activation_instructions]

  def activation_instructions(email_config)
    headers = {
      :subject => "#{email_config.account.portal_name} email activation instructions",
      :from    => email_config.account.default_friendly_email,
      :to      => email_config.reply_email,
      :sent_on => Time.now,
      "Reply-to" => "#{email_config.account.default_friendly_email}", 
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    headers.merge!(make_header(nil, nil, email_config.account_id, "Email Config Activation Instructions"))
    @activation_url = admin_register_email_url(email_config.activator_token, 
                        :host => email_config.account.host, :protocol => email_config.account.url_protocol)
    @email_config   = email_config
    mail(headers) do |part|
      part.html { render "activation_instructions.html" }
    end.deliver
    Rails.logger.info "Sending activation instructions for email_config - #{email_config.reply_email} - #{@activation_url.to_s}"
  end
  
  def test_email(email_config)
    headers = {
      :subject => "Woohoo.. Your Freshdesk Test Mail",
      :from    => "#{AppConfig['app_name']} Test <#{Helpdesk::EMAIL[:default_requester_email]}>",
      :to      => email_config.reply_email,
      :sent_on => Time.now,
      "Reply-to" => "#{Helpdesk::EMAIL[:default_requester_email]}", 
      "Auto-Submitted" => "auto-generated", 
      "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    }
    headers.merge!(make_header(nil, nil, email_config.account_id, "Freshdesk Test Email"))
    @email_config = email_config
    mail(headers) do |part|
      part.html { render "test_email" }
    end.deliver
  end

  # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
  # Keep this include at end
  include MailerDeliverAlias 
end
