class UserNotifier < ActionMailer::Base
  
  def user_activation(user, params)
    subject       params[:subject]
    body          params[:email_body]
    send_the_mail (user, params[:reply_email])
  end
  
  def password_reset_instructions(user, params)
    subject       params[:subject]
    body          params[:email_body]
    send_the_mail (user, params[:reply_email])
  end
  
  def send_the_mail(user , reply_email =nil)
    from          reply_email || user.account.default_friendly_email
    recipients    user.email
    sent_on       Time.now
    headers       "Reply-to" => "#{user.account.default_friendly_email}"
    content_type  "text/plain"
  end
  
  def account_admin_activation(account_admin)
    from  AppConfig['from_email'] 
    recipients account_admin.email
    subject "#{AppConfig['app_name']} account Activation"
    sent_on Time.now
    body (:account_admin => account_admin, 
          :activation_url => register_url(:activation_code => account_admin.perishable_token, :host => account_admin.account.host))
    content_type  "text/html"
  end
  
end
