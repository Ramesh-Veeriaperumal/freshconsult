class EmailConfigNotifier < ActionMailer::Base
  
  layout "email_font", :except => [:activation_instructions]

  def activation_instructions(email_config)
    subject       "#{email_config.account.portal_name} email activation instructions"
    body          :activation_url => admin_register_email_url(email_config.activator_token, 
                    :host => email_config.account.host), :email_config => email_config
    from          email_config.account.default_friendly_email
    recipients    email_config.reply_email
    sent_on       Time.now
    headers       "Reply-to" => "#{email_config.account.default_friendly_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    content_type  "text/plain"
  end
  
  def test_email(email_config)
    subject       "Wohoo.. Your Freshdesk Test Mail"
    body          :email_config => email_config
    from          "Freshdesk Test <rachel@freshdesk.com>"
    recipients    email_config.reply_email
    sent_on       Time.now
    headers       "Reply-to" => "rachel@freshdesk.com", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    content_type  "text/html"
  end  
end
