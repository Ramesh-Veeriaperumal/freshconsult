module Va::Webhook::Trigger

  include Va::Webhook::Util
  include Va::Webhook::ThrottlerUtil
  include Redis::RedisKeys
  include Redis::OthersRedis

  def trigger_webhook(act_on)
    act_hash[:url].delete!(' ')
    content_type  = act_hash[:content_type].to_i
    auth_header   = generate_auth_header
    params        = generate_params act_on, content_type
    custom_headers = act_hash[:custom_headers]

    if act_hash[:content_layout].to_i == SIMPLE_WEBHOOK
      params[:body] = generate_body_from_hash act_on, content_type
    else
      params[:body] = substitute_placeholders_in_format(act_on, :params, content_type)
    end

    throttler_args = {
      :params => params,
      :retry_count => 0,
      :auth_header => auth_header,
      :custom_headers => custom_headers,
      :rule_id => self.va_rule.id,
      :account_id => Account.current.id,
      :webhook_created_at => Time.now.utc.to_f,
      :webhook_limit => Account.current.account_additional_settings_from_cache.webhook_limit
    }
    
    if redis_key_exists?(WEBHOOK_V1_ENABLED)
      ::WebhookV1Worker.perform_async(throttler_args)
    elsif Account.current.premium_webhook_throttler?
      Throttler::PremiumWebhookThrottler.perform_async({
        :args => throttler_args
      })
    else
      Throttler::WebhookThrottler.perform_async({
        :args => throttler_args
      })
    end
  end
end
