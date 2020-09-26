module Freshfone::CustomForwardingUtil
  include Redis::RedisKeys
  include Redis::IntegrationsRedis

  MAX_INPUT_LIMIT = 3

  RESPONSE_HASH = {
    accept: 1,
    reject: 2
  }

  RESPONSE_HASH.each_pair do |k, v|
    define_method("custom_forward_#{k}?") do
      v == params[:Digits].to_i
    end
  end
  
  def custom_forwarding_enabled?
    current_account.features?(:freshfone_custom_forwarding)
  end

  def caller_name
    current_call.customer_name || current_call.caller.name_or_location
  end

  def render_invalid_input(url, caller_name)
    return empty_twiml if input_limit_exceeded?
    render xml: telephony.forward_invalid_option(url, caller_name,
      current_call.freshfone_number.voice_type)
  end

  def input_limit_exceeded?
    key = activation_key
    incr_val(key) == MAX_INPUT_LIMIT
  end

  def activation_key
    INVALID_FORWARD_INPUT_COUNT % { account_id: current_account.id,
      call_id: current_call.id }
  end
end
