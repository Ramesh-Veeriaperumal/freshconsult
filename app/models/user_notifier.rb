class UserNotifier < ActionMailer::Base
  #to do some job for password reset. by Shan
  def activation_instructions(user)
    subject       "Activation Instructions"
    from          Helpdesk::EMAIL[:from]
    recipients    user.email
    sent_on       Time.now
    body          :account_activation_url => register_url(user.perishable_token, :host => Helpdesk::HOST[RAILS_ENV.to_sym])
    headers       "Reply-to" => "#{Helpdesk::EMAIL[:from]}"
    content_type  "text/plain"
  end

  def activation_confirmation(user)
    subject       "Activation Complete"
    from          Helpdesk::EMAIL[:from]
    recipients    user.email
    sent_on       Time.now
    body          :root_url => root_url(:host => Helpdesk::HOST[RAILS_ENV.to_sym])
  end
end
