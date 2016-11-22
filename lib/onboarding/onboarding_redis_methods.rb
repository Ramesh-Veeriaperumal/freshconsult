module Onboarding::OnboardingRedisMethods
  include Redis::RedisKeys
  include Redis::OthersRedis

  def account_onboarding_pending?
    get_others_redis_key(account_onboarding_redis_key).present?
  end

  def complete_account_onboarding
    remove_others_redis_key(account_onboarding_redis_key)
  end

  def set_account_onboarding_pending
    set_others_redis_key(account_onboarding_redis_key, true, account_onboarding_redis_expiry)
  end

  def account_onboarding_redis_key
    ACCOUNT_ONBOARDING_PENDING % { :account_id => Account.current.id }
  end

  private
    def account_onboarding_redis_expiry
      45.days
    end
end
