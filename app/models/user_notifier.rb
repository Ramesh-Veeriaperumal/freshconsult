class UserNotifier < ActionMailer::Base
  
  def user_activation(user, params)
    subject       params[:subject]
    body          params[:email_body]
    send_the_mail user
  end
  
  def password_reset_instructions(user, params)
    subject       "#{user.account.portal_name} password reset instructions"
    body          params[:email_body]
    send_the_mail user
  end
  
  def send_the_mail(user)
    from          user.account.default_email
    recipients    user.email
    sent_on       Time.now
    headers       "Reply-to" => "#{user.account.default_email}"
    content_type  "text/plain"
  end
  
end
