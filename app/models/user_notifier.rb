class UserNotifier < ActionMailer::Base
  def agent_activation(user)
    subject         "#{user.account.helpdesk_name} agent activation"
    send_activation user
  end
  
  def user_activation(user)
    subject        "#{user.account.helpdesk_name} user activation"
    send_activation user
  end
  
  def agent_confirmation(user)
    subject           "#{user.account.helpdesk_name} agent activation complete"
    send_confirmation user
  end
  
  def user_confirmation(user)
    subject           "#{user.account.helpdesk_name} user activation complete"
    send_confirmation user
  end
  
  def password_reset_instructions(user)
    subject       "#{user.account.helpdesk_name} password reset instructions"
    body          :edit_password_reset_url => edit_password_reset_url(user.perishable_token, :host => user.account.host)
    send_the_mail user
  end
  
  def send_activation(user)
    body          :account_activation_url => register_url(user.perishable_token, :host => user.account.host), :user => user
    send_the_mail user
  end
  
  def send_confirmation(user)
    body          :root_url => root_url(:host => user.account.host), :user => user
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
