module SupportTicketRateLimitMethods
  include Redis::RedisKeys
  include Redis::OthersRedis

  def enforce_captcha?(captcha_enabled_for_anonymous)
    return true if captcha_enabled_for_anonymous && !current_user
    get_others_redis_key(limit_key).to_i > AppConfig['support_ticket_rate_limit'] if current_user && current_user.customer?
  end

  def show_captcha?(captcha_enabled_for_anonymous)
    return true if captcha_enabled_for_anonymous && !current_user
    get_others_redis_key(limit_key).to_i >= AppConfig['support_ticket_rate_limit'] if current_user && current_user.customer?
  end

  def check_and_increment_usage
    return unless current_user && current_user.customer?
    redis_key_exists?(limit_key) ? increment_others_redis(limit_key, 1) : set_key_with_expiry(limit_key)
  end

  def set_key_with_expiry(key)
    set_others_redis_with_expiry(key, 1, ex: AppConfig['support_ticket_rate_limit_period'])
  end

  def limit_key
    format(SUPPORT_TICKET_LIMIT, account_id: current_account.id, user_id: current_user.id)
  end
end
