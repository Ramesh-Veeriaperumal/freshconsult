module Helpdesk::SpamAccountConstants

  include Redis::RedisKeys
  include Redis::OthersRedis

  MAX_TO_CC_THRESHOLD = 10
  FREE_ACCOUNT_OUTBOUND_DEFAULT_THRESHOLD = 30
  ACCOUNT_ID_THRESHOLD = 400000
  TRIAL_ACCOUNT_OUTBOUND_DEFAULT_THRESHOLD = 5
  SPAM_CHECK_TIME_LIMIT = 30 #in days

  	def get_trial_account_max_to_cc_threshold
      if $trial_account_max_to_cc_threshold.blank?
  		  to_cc_threshold = get_others_redis_key(TRIAL_ACCOUNT_MAX_TO_CC_THRESHOLD)
  		  $trial_account_max_to_cc_threshold = to_cc_threshold.present? ? to_cc_threshold.to_i : MAX_TO_CC_THRESHOLD
      end
  		return $trial_account_max_to_cc_threshold
  	end

    def get_free_account_outbound_threshold
      if $free_account_outbound_threshold.blank?
        free_account_threshold = get_others_redis_key(FREE_ACCOUNT_OUTBOUND_THRESHOLD)
        $free_account_outbound_threshold = free_account_threshold.present? ? free_account_threshold.to_i : FREE_ACCOUNT_OUTBOUND_DEFAULT_THRESHOLD
      end
      return $free_account_outbound_threshold
    end

    def email_threshold_crossed_tickets account_id, ticket_id
      key = EMAIL_THRESHOLD_CROSSED_TICKETS % { :account_id => account_id}
      ticket_ids = get_all_members_in_a_redis_set(key)
      unless ticket_ids.present?
        set_others_redis_expiry(key,86400) 
        ticket_ids = []
      end
      add_member_to_redis_set(key,ticket_id)
      ticket_ids << "#{ticket_id}" unless ticket_ids.include?("#{ticket_id}")
      ticket_ids
    end

  	def get_spam_account_id_threshold
      if $trial_account_id_spam_threshold.blank?
  		  account_id_threshold = get_others_redis_key(SPAM_ACCOUNT_ID_THRESHOLD)
  		  $trial_account_id_spam_threshold = account_id_threshold.present? ? account_id_threshold.to_i : ACCOUNT_ID_THRESHOLD
      end
  		return $trial_account_id_spam_threshold
  	end

    def get_spam_check_time_limit
      if $spam_account_time_limit.blank?
        time_limit = get_others_redis_key(SPAM_ACCOUNT_TIME_LIMIT)
        $spam_account_time_limit = time_limit.present? ? time_limit.to_i : SPAM_CHECK_TIME_LIMIT
      end
      return $spam_account_time_limit
    end

    def account_created_recently?
      if Account.current
        account_time_limit = get_spam_check_time_limit
        return Account.current.created_at > account_time_limit.days.ago
      end
      return false
    end
end
