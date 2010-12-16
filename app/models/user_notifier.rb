class UserNotifier < ActionMailer::Base
  #to do some job for password reset. by Shan
  def activation_instructions(user)
    subject       "Freshdesk user activation instructions"
    from          user.account.default_email
    recipients    user.email
    sent_on       Time.now
    body          :account_activation_url => register_url(user.perishable_token, :host => user.account.full_domain)
    headers       "Reply-to" => "#{user.account.default_email}"
    content_type  "text/plain"
  end

  def activation_confirmation(user)
    subject       "Freshdesk user activation complete"
    from          user.account.default_email
    recipients    user.email
    sent_on       Time.now
    body          :root_url => root_url(:host => user.account.full_domain)
    headers       "Reply-to" => "#{user.account.default_email}"
    content_type  "text/plain"
  end
  
end
