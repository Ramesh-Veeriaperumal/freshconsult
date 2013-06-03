class UserNotifier < ActionMailer::Base
  layout "email_font"
  def user_activation(user, params)
    subject       params[:subject]
    send_the_mail(user, params[:email_body], params[:reply_email])
  end
  
  def password_reset_instructions(user, params)
    subject       params[:subject]
    send_the_mail(user, params[:email_body], params[:reply_email])
  end
  
  def send_the_mail(user, email_body, reply_email =nil)
    from          reply_email || user.account.default_friendly_email
    recipients    user.email
    sent_on       Time.now
    headers       "Reply-to" => "#{user.account.default_friendly_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    content_type  "text/html"
    
    part "text/html" do |html|
      html.body   render_message("user_notification_mail", :body => email_body)
    end
  end
  
  def account_admin_activation(account_admin)
    from  AppConfig['from_email'] 
    recipients account_admin.email
    subject "#{AppConfig['app_name']} Account Activation"
    sent_on Time.now
    body(:account_admin => account_admin, 
          :activation_url => register_url(:activation_code => account_admin.perishable_token, :host => account_admin.account.host , :protocol => account_admin.url_protocol ))
    content_type  "text/html"
  end

  def custom_ssl_activation(account_admin, portal_url, elb_name)
    from          AppConfig['from_email']
    recipients    account_admin.email
    subject       "Custom SSL Activated"
    body          :account_admin_name => account_admin.name, :portal_url => portal_url, :elb_name => elb_name
    sent_on       Time.now
  end

  def notify_contacts_import(user)
    subject       "Contacts Import for #{user.account.full_domain}"
    recipients    user.email
    from          user.account.default_friendly_email
    body          :user => user
    sent_on       Time.now
    headers       "Reply-to" => "#{user.account.default_friendly_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    content_type  "text/html"
  end

  
end
