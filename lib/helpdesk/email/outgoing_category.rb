module Helpdesk::Email::OutgoingCategory

  require 'freemail'

  include Redis::RedisKeys
  include Redis::OthersRedis
  include Spam::SpamAction
  include Helpdesk::SpamAccountConstants

  CATEGORIES = [
    [:trial,      1],
    [:active,     2],
    [:premium,    3],
    [:free,       4],
    [:default,    5],
    [:spam,       9]  
  ]
  
  CATEGORY_BY_TYPE = Hash[*CATEGORIES.flatten]
  CATEGORY_SET = CATEGORIES.map{|a| a[0]}
  
  def get_subscription
    state = nil
    if Account.current
      state = "premium" if Account.current.premium_email? 
      state ||= Account.current.subscription.state 
    end
    state = "default" if (state.nil?) or (!CATEGORY_SET.include?(state.to_sym))
    return state
  end

  def get_category_id
    key = get_subscription
    if  ( (!account_whitelisted?) &&
          (account_created_recently? || 
            ( (key == "trial") && 
            ( ismember?(BLACKLISTED_SPAM_ACCOUNTS, Account.current.id) || Freemail.free_or_disposable?(Account.current.admin_email))
            )))
      key = "spam"
    end 
    CATEGORY_BY_TYPE[key.to_sym]
  end

  def account_whitelisted?
    if Account.current
      return ismember?(SPAM_WHITELISTED_ACCOUNTS, Account.current.id)
    end
    return false
  end

  def account_created_recently?
    if Account.current
      account_time_limit = get_spam_check_time_limit
      return Account.current.created_at > account_time_limit.days.ago
    end
    return false
  end
end
