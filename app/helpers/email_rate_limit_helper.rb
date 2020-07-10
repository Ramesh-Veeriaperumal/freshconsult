module EmailRateLimitHelper
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Helpdesk::Email::Constants

  def rate_limit_count_key(account_id, hour, quadrant)
    format(EMAIL_RATE_LIMIT_COUNT, account_id: account_id, hour_quadrant: hour.to_s + quadrant.to_s)
  end

  def rate_limit_breached_key(account_id)
    format(EMAIL_RATE_LIMIT_BREACHED, account_id: account_id)
  end

  def rate_limit_admin_notify_key(account_id)
    format(EMAIL_RATE_LIMIT_ADMIN_NOTIFIED, account_id: account_id)
  end

  def notify_admins_on_email_rate_limit_breach
    UserNotifier.send_email_to_group(:notify_email_rate_limit_exceeded, Account.current.fetch_all_admins_email)
  rescue StandardError => e
    Rails.logger.error "Error sending rate limit email notification to admins for AccountID - #{Account.current.id}. Error - #{e.message}"
  end

  def increment_email_rate_limit_count(rate_limit_count_key, expiry)
    count = increment_others_redis(rate_limit_count_key)
    set_others_redis_expiry(rate_limit_count_key, expiry)
    count.to_i
  end

  def process_email_rate_limiting(account_id, time)
    hour = time.hour
    min = time.min
    sec = time.sec
    rate_limit_dedup_key = rate_limit_dedup_key(account_id, min)
    value = set_others_redis_key_if_not_present(rate_limit_dedup_key, 1)
    # return if we get the rate-limit event within same minute
    return if value == false

    # set rate_limit_dedup_key with expiry of 2 minutes for additional buffer
    set_others_redis_expiry(rate_limit_dedup_key, 2.minutes)
    # devide 1 hr in 4 quadrants of 15 min
    quadrant = min / 15 + 1
    # set expiry as 15 min plus remaining time in current quadrant from Time.now
    expiry = 30.minutes - (min % 15).minutes - sec.seconds
    rate_limit_count_key = rate_limit_count_key(account_id, hour, quadrant)
    rate_limit_breached_key = rate_limit_breached_key(account_id)
    rate_limit_email_admin_notify_key = rate_limit_admin_notify_key(account_id)
    rate_limit_count = increment_email_rate_limit_count(rate_limit_count_key, expiry)
    notify_email_rate_limit_breached(rate_limit_breached_key, rate_limit_email_admin_notify_key, rate_limit_count, expiry)
  end

  def notify_email_rate_limit_breached(rate_limit_breached_key, rate_limit_email_admin_notify_key, count, expiry)
    if count >= EMAIL_RATE_LIMIT_BANNER_THRESHOLD
      set_others_redis_key(rate_limit_breached_key, 1, expiry)
    else
      # increase expiry of breached key if breached key exists and we get rate limit event for the next quadrant
      set_others_redis_expiry(rate_limit_breached_key, expiry)
    end
    send_email_on_rate_limit_breach(rate_limit_email_admin_notify_key) if redis_key_exists?(rate_limit_breached_key) && !redis_key_exists?(rate_limit_email_admin_notify_key)
  end

  def send_email_on_rate_limit_breach(rate_limit_email_admin_notify_key)
    # Send email to admins only once a day
    set_others_redis_key_if_not_present(rate_limit_email_admin_notify_key, 1)
    set_others_redis_expiry(rate_limit_email_admin_notify_key, EMAIL_RATE_LIMIT_ADMIN_ALERT_EXPIRY)
    notify_admins_on_email_rate_limit_breach
  end

  def rate_limit_dedup_key(account_id, min)
    format(EMAIL_RATE_LIMIT_DEDUP, account_id: account_id, minute: min)
  end
end
