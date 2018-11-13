module ApiEmailNotificationConstants
  VALIDATION_CLASS = 'EmailNotificationValidation'.freeze
  UPDATE_FIELDS = %i[requester_notification requester_subject_template requester_template agent_notification agent_subject_template agent_template].freeze
  CUSTOM_NOTIFICATIONS = [
    [EmailNotification::BOT_RESPONSE_TEMPLATE, :bot_email_channel, 'default_bot_email_response']
  ]
  CUSTOM_NOTIFICATIONS_FEATURE_BY_TYPE = Hash[*CUSTOM_NOTIFICATIONS.map{|i| [i[0], i[1]]}.flatten]
  CUSTOM_NOTIFICATIONS_DEFAULT_TEMPLATE_BY_TYPE = Hash[*CUSTOM_NOTIFICATIONS.map{|i| [i[0], i[2]]}.flatten]
end
