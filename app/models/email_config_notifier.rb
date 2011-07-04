class EmailConfigNotifier < ActionMailer::Base
  def activation_instructions(email_config)
    subject       "#{email_config.account.portal_name} email activation instructions"
    body          :activation_url => admin_register_email_url(email_config.activator_token, 
                    :host => email_config.account.host), :email_config => email_config
    from          email_config.account.default_email
    recipients    email_config.reply_email
    sent_on       Time.now
    headers       "Reply-to" => "#{email_config.account.default_email}"
    content_type  "text/plain"
  end
end
