module Mobile::Actions::Push_Notifier

	include Redis::RedisKeys
	include Mobile::Constants
	include Redis::MobileRedis
	include Mobile::IrisPushNotifications::FreshfoneEvents::IncomingCall

  def freshfone_notify_incoming_call(message)
    user_ids = message[:agents]
    message[:freshfone_notification_type] = message[:notification_type]
    message.merge!(:notification_types => { IRIS_FRESHFONE_NOTIFCATION_TYPES[:FRESHFONE_INCOMING_CALL] => user_ids })
    channel_id = message[:account_id]%MOBILE_NOTIFICATION_CHANNEL_COUNT
    Rails.logger.debug "DEBUG :: freshfone_notify_incoming_call hash : #{message}"
		notify_incoming_call_event_to_iris(notification_params)
  end

end
