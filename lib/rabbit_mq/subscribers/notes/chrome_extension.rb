module RabbitMq::Subscribers::Notes::ChromeExtension
  def mq_chrome_extension_valid
    true
  end

  def mq_chrome_extension_note_properties(action)
    properties = get_properties(notable)
    properties["users_notify"] = users_to_be_notified
    properties["actions"].push(action)
    properties
  end

  def mq_chrome_extension_subscriber_properties
    {}
  end


  private

  def users_to_be_notified
    user_ids = notable.subscriptions.map(&:user_id)    
    user_ids.push(notable.responder_id) unless notable.responder_id.blank?

    unless incoming || self.to_emails.blank? || !self.note?
      notified_agent_emails =  self.to_emails.map { |email| parse_email_text(email)[:email] }
      user_ids = user_ids | account.users.find(:all, :select => :id , :conditions => {:email => notified_agent_emails, :helpdesk_agent => 1}).map(&:id)
    end    
    
    user_ids.uniq
  end

end