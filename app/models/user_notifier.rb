class UserNotifier < ActionMailer::Base
  
  def user_activation(user, params)
    subject       params[:subject]
    body          params[:email_body]
    send_the_mail user
  end
  
  def password_reset_instructions(user)
    subject       "#{user.account.helpdesk_name} password reset instructions"
    body          :edit_password_reset_url => edit_password_reset_url(user.perishable_token, :host => user.account.host)
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
