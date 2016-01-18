module Spam::SpamAction
  include Redis::RedisKeys
  include Redis::OthersRedis  
  
  def detect_spam_action
    return if account_whitelisted?
    @errors ||= []
    email_domain = current_user.email.split("@").last.downcase
    
    if domain_check(email_domain) && (3.days.ago < current_account.created_at) 
      if has_less_open_tickets?
        Rails.logger.debug "Account #{current_account.id} is prevented from updating email notification template." +            "Params used are email domain - #{email_domain} and user id - #{current_user.id}"
        @errors << t("email_notification.spam_error")
      end  
    end
  end
  
  def account_whitelisted?
    !get_others_redis_key(notification_whitelisted_key(current_account.id)).nil?
  end
  
  def notification_whitelisted_key(account)
    SPAM_NOTIFICATION_WHITELISTED_DOMAINS_EXPIRY % {:account_id => account}
  end
  
  def domain_check(email_domain)
    ismember?(SPAM_USER_EMAIL_DOMAINS, email_domain)
  end
  
  def has_less_open_tickets?
    current_account.tickets.limit(11).count < 10
  end
end