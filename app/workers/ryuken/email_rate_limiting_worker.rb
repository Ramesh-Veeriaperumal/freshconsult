class Ryuken::EmailRateLimitingWorker
  include Shoryuken::Worker
  include EmailRateLimitHelper
  include Redis::OthersRedis

  shoryuken_options queue: SQS[:email_rate_limiting_queue], auto_delete: true, body_parser: :json

  EMAIL_RATE_LIMIT_BANNER_THRESHOLD = 8
  FRESHDESK_PRODUCT_FILTER = 'FRESHDESK_EMAIL'.freeze

  def perform(sqs_msg, _args)
    data = JSON.parse(sqs_msg.body)['data']
    data.deep_symbolize_keys!
    return unless validate_params(data[:payload])

    begin
      account_id = data[:account_id]
      time = Time.now.in_time_zone
      hour = time.hour
      min = time.min
      sec = time.sec
      # devide 1 hr in 4 quadrants of 15 min
      quadrant = min / 15 + 1
      # set expiry as 15 min plus remaining time in current quadrant from Time.now
      expiry = 30.minutes - (min % 15).minutes - sec.seconds
      rate_limit_count_key = rate_limit_count_key(account_id, hour, quadrant)
      count = increment_email_rate_limit_count(rate_limit_count_key, expiry)
      rate_limit_breached_key = rate_limit_breached_key(account_id)
      set_email_rate_limit_breached(rate_limit_breached_key, count, expiry)
    end
  rescue StandardError => e
    NewRelic::Agent.notice_error(e, description: "Error while processing Email Rate Limiting message #{e}")
    Rails.logger.error "Error while processing Email Rate Limiting message :: #{account_id} :: #{e.message} :: #{e.backtrace[0..10]}"
  end

  private

    def validate_params(payload)
      product = payload.try(:[], :product)
      product == FRESHDESK_PRODUCT_FILTER
    end

    def increment_email_rate_limit_count(rate_limit_count_key, expiry)
      count = increment_others_redis(rate_limit_count_key)
      set_others_redis_expiry(rate_limit_count_key, expiry)
      count.to_i
    end

    def set_email_rate_limit_breached(rate_limit_breached_key, count, expiry)
      if count >= EMAIL_RATE_LIMIT_BANNER_THRESHOLD
        set_others_redis_key(rate_limit_breached_key, 1, expiry)
      else
        # increase expiry of breached key if breached key exists and we get rate limit event for the next quadrant
        set_others_redis_expiry(rate_limit_breached_key, expiry)
      end
    end
end
