module Freshfone::CallbackUrls
  include FreshfoneHelper

  def ops_call_notify_url
    "#{host}/freshfone/ops_notification/voice_notification"
  end

  def usage_trigger_url
    "#{host}/freshfone/usage_triggers/notify"
  end

end