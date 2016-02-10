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

    Throttler::WebhookThrottler.perform_async({
      :args => {
        :params => params,
        :retry_count => 0,
        :auth_header => auth_header,
        :custom_headers => custom_headers,
        :rule_id => self.va_rule.id,
        :account_id => Account.current.id
      }
    })
  end
end
