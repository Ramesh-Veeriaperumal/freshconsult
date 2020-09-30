module Helpdesk::Email::OutgoingCategory

  require 'freemail'

  include Redis::RedisKeys
  include Redis::OthersRedis
  include Spam::SpamAction
  include Helpdesk::SpamAccountConstants
  include EmailHelper

  CATEGORIES = [
    [:trial,      1],
    [:active,     2],
    [:premium,    3],
    [:free,       4],
    [:default,    5],
    [:spam,       9],
    [:paid_email_notification, 20],
    [:free_email_notification, 21]
  ]

#for default we still use sendgrid for outgoing- due to DKIM
  MAILGUN_CATEGORIES = [
    [:trial,      11],
    [:active,     12],
    [:premium,    13],
    [:free,       14],
    [:default,    5],
    [:spam,       19]
  ]
  
  CATEGORY_BY_TYPE = Hash[*CATEGORIES.flatten]
  MAILGUN_CATEGORY_BY_TYPE = Hash[*MAILGUN_CATEGORIES.flatten]
  CATEGORY_SET = CATEGORIES.map{|a| a[0]}
  MAILGUN_PROVIDERS = MAILGUN_CATEGORY_BY_TYPE.values.select do |value| value > 10 end 
  
  def get_subscription
    state = nil
    if Account.current
      state = "premium" if Account.current.premium_email? 
      state ||= Account.current.subscription.state if Account.current.subscription.present?
    end
    state = "default" if (state.nil?) or (!CATEGORY_SET.include?(state.to_sym))
    return state
  end

  def get_category_id(use_mailgun = false)
    key = get_subscription
    if !account_whitelisted?
      if ((key == "trial") && (Account.current.spam_blacklist_feature_enabled? ||
                 Freemail.free_or_disposable?(Account.current.admin_email)))
        key = "spam"
      elsif( account_created_recently?)
        key = "trial"
      end
    end
    if use_mailgun
      MAILGUN_CATEGORY_BY_TYPE[key.to_sym]
    else 
      CATEGORY_BY_TYPE[key.to_sym]
    end
  end

  def account_whitelisted?
    if Account.current
      return ismember?(SPAM_WHITELISTED_ACCOUNTS, Account.current.id)
    end
    return false
  end


  def get_mailgun_percentage
    if eval("$#{get_subscription}_mailgun_percentage").blank? || eval("$#{get_subscription}_last_time_checked").blank? || eval("$#{get_subscription}_last_time_checked") < 5.minutes.ago
      eval("$#{get_subscription}_mailgun_percentage = #{get_others_redis_key(Object.const_get("Redis::RedisKeys::#{(get_subscription).upcase}_MAILGUN_TRAFFIC_PERCENTAGE")).to_i}")
      eval("$#{get_subscription}_last_time_checked = Time.now")
    end
    return eval("$#{get_subscription}_mailgun_percentage")
  end

  def custom_category_enabled_notifications
    if ($custom_category_notifications.blank? || $notifications_checked_time.blank? || $notifications_checked_time < 5.minutes.ago)
      notificatons_list = get_all_members_in_a_redis_set(CUSTOM_CATEGORY_NOTIFICATIONS).map { |e| e.to_i }
      $custom_category_notifications = (notificatons_list.present? ? 
                  notificatons_list : EmailNotification::CUSTOM_CATEGORY_ID_ENABLED_NOTIFICATIONS)
      $notifications_checked_time = Time.now
    end
    return $custom_category_notifications
  end

  def spam_filtered_notifications
    if ($spam_filtered_notifications.blank? || $spam_checked_time.blank? || $spam_checked_time < 5.minutes.ago)
      notificatons_list = get_all_members_in_a_redis_set(SPAM_FILTERED_NOTIFICATIONS).map { |e| e.to_i }
      $spam_filtered_notifications = (notificatons_list.present? ?
                                          notificatons_list : EmailNotification::SPAM_FILTERED_NOTIFICATIONS)
      $spam_checked_time = Time.now
    end
    return $spam_filtered_notifications
  end

  def spam_blacklisted_rules
    if ($spam_blacklisted_rules.blank? || $spam_rules_checked_time.blank? || $spam_rules_checked_time < 5.minutes.ago)
      rules_list = get_all_members_in_a_redis_set(SPAM_BLACKLISTED_RULES)
      $spam_blacklisted_rules = (rules_list.present? ?
                                     rules_list : ["test_rule"])
      $spam_rules_checked_time = Time.now
    end
    return $spam_blacklisted_rules
  end

  def check_spam_rules(spam_response)
    blacklisted_rules = spam_blacklisted_rules
    if spam_response.rules.blank? || blacklisted_rules.blank?
      return
    end
    spam_response.rules.each do |rule|
      if blacklisted_rules.include?(rule)
        curr_account = Account.current
        if curr_account.present? && !ismember?(SPAM_EMAIL_ACCOUNTS, curr_account.id)
          add_member_to_redis_set(SPAM_EMAIL_ACCOUNTS, curr_account.id) if !(curr_account.subscription.active?)
          notify_outgoing_block(curr_account, rule)
          break
        end
      end
    end
  end


  def notify_outgoing_block(account, rules)
    subject = "Detected suspicious spam account :#{account.id}" #should be called only when account object is set
    additional_info = "Emails sent by the account has suspicious content . Contains content blacklisted by rule : #{rules} ."
    additional_info << "Outgoing emails blocked!!" if !(Account.current.subscription.active?)
    notify_account_blocks(account, subject, additional_info)
    update_freshops_activity(account, "Outgoing emails blocked due to blacklisted spam rules match", "block_outgoing_email") if !(Account.current.subscription.active?)
  end

end
