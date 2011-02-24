class UserNotifier < ActionMailer::Base
  def activation_instructions(user)
    subject       "#{user.account.helpdesk_name} user activation instructions"
    body          :account_activation_url => register_url(user.perishable_token, :host => user.account.host)
    send_the_mail user
  end

  def activation_confirmation(user)
    subject       "#{user.account.helpdesk_name} user activation complete"
    body          :root_url => root_url(:host => user.account.host)
    send_the_mail user
  end
  
  def password_reset_instructions(user)
    subject       "#{user.account.helpdesk_name} Password Reset Instructions"
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
