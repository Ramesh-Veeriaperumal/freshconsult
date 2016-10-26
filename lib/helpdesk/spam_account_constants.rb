module Helpdesk::SpamAccountConstants

	include Redis::RedisKeys
  	include Redis::OthersRedis

  	MAX_TO_CC_THRESHOLD = 10
  	ACCOUNT_ID_THRESHOLD = 400000

    SPAM_CHECK_TIME_LIMIT = 30 #in days

  	def get_trial_account_max_to_cc_threshold
      if $trial_account_max_to_cc_threshold.blank?
  		  to_cc_threshold = get_others_redis_key(TRIAL_ACCOUNT_MAX_TO_CC_THRESHOLD)
  		  $trial_account_max_to_cc_threshold = to_cc_threshold.present? ? to_cc_threshold.to_i : MAX_TO_CC_THRESHOLD
      end
  		return $trial_account_max_to_cc_threshold
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
end
