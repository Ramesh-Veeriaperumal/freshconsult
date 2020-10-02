module EmailSettingsConstants
  VALIDATION_CLASS = 'Email::SettingsValidation'.freeze
  UPDATE_FIELDS = %w[personalized_email_replies create_requester_using_reply_to allow_agent_to_initiate_conversation original_sender_as_requester_for_forward].freeze
  COMPOSE_EMAIL = :compose_email
  DISABLE_AGENT_FORWARD = :disable_agent_forward
  EMAIL_SETTINGS_PARAMS_MAPPING = {
    create_requester_using_reply_to: :reply_to_based_tickets,
    original_sender_as_requester_for_forward: DISABLE_AGENT_FORWARD,
    allow_agent_to_initiate_conversation: COMPOSE_EMAIL
  }.freeze
end
