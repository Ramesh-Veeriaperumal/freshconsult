module Spam::SpamAction
  include Redis::RedisKeys
  include Redis::OthersRedis  
  
  def detect_spam_action
    return if account_whitelisted?
    @errors ||= []
    email_domain = current_user.email.split("@").last.downcase
    
    if domain_check(email_domain) && (3.days.ago < current_account.created_at) 
      if has_less_open_tickets?
        @errors << t("email_notification.spam_error")
      end  
    end
  end
  
  def account_whitelisted?
    all_accounts = get_all_members_in_a_redis_set(SPAM_NOTIFICATION_WHITELISTED_DOMAINS)
    valid_accounts = []
    all_accounts.each do |account_id|
      if get_others_redis_key(notification_whitelisted_key(account_id)).nil?
        remove_member_from_redis_set(SPAM_NOTIFICATION_WHITELISTED_DOMAINS, account_id)
      else
        valid_accounts << account_id
      end
    end
    valid_accounts.include?(current_account.id.to_s)
  end
  
  def notification_whitelisted_key(account)
    SPAM_NOTIFICATION_WHITELISTED_DOMAINS_EXPIRY % {:account_id => account}
  end
  
  def domain_check(email_domain)
    ismember?(SPAM_USER_EMAIL_DOMAINS, email_domain)
  end
  
  def has_less_open_tickets?
    current_account.tickets.where(:status => Helpdesk::Ticketfields::TicketStatus::OPEN).limit(11).count < 11
  end
end