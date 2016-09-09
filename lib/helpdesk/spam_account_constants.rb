module Helpdesk::SpamAccountConstants

	include Redis::RedisKeys
  	include Redis::OthersRedis

  	MAX_TO_CC_THRESHOLD = 10
  	ACCOUNT_ID_THRESHOLD = 400000

  	def get_trial_account_max_to_cc_threshold
  		to_cc_threshold = get_others_redis_key(TRIAL_ACCOUNT_MAX_TO_CC_THRESHOLD) if $trial_account_max_to_cc_threshold.blank?
  		$trial_account_max_to_cc_threshold ||= to_cc_threshold.present? ? to_cc_threshold.to_i : MAX_TO_CC_THRESHOLD
  		return $trial_account_max_to_cc_threshold
  	end

  	def get_spam_account_id_threshold
  		account_id_threshold = get_others_redis_key(SPAM_ACCOUNT_ID_THRESHOLD) if $trial_account_id_spam_threshold.blank?
  		$trial_account_id_spam_threshold ||= account_id_threshold.present? ? account_id_threshold.to_i : ACCOUNT_ID_THRESHOLD
  		return $trial_account_id_spam_threshold
  	end
end
