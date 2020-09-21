module EmailSettingsConstants
  VALIDATION_CLASS = 'Email::SettingsValidation'.freeze
  DELEGATOR_CLASS = 'Email::SettingsDelegator'.freeze
  UPDATE_FIELDS = %w[personalized_email_replies create_requester_using_reply_to allow_agent_to_initiate_conversation original_sender_as_requester_for_forward].freeze
  COMPOSE_EMAIL_SETTING = :compose_email
  DISABLE_AGENT_FORWARD = :disable_agent_forward
  EMAIL_CONFIG_PARAMS = {
    create_requester_using_reply_to: :reply_to_based_tickets,
    original_sender_as_requester_for_forward: :disable_agent_forward,
    allow_agent_to_initiate_conversation: :compose_email,
    personalized_email_replies: :personalized_email_replies
  }.freeze
end
