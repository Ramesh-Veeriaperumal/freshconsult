module EmailSettingsConstants
  VALIDATION_CLASS = 'Email::SettingsValidation'.freeze
  DELEGATOR_CLASS = 'Email::SettingsDelegator'.freeze
  UPDATE_FIELDS = %w[personalized_email_replies create_requester_using_reply_to allow_agent_to_initiate_conversation original_sender_as_requester_for_forward].freeze
  COMPOSE_EMAIL_SETTING = :compose_email
  NEGATION_SETTINGS = [:disable_agent_forward].freeze
  EMAIL_SETTINGS_PARAMS_NAME_CHANGES = {
    create_requester_using_reply_to: :reply_to_based_tickets,
    original_sender_as_requester_for_forward: :disable_agent_forward,
    allow_agent_to_initiate_conversation: :compose_email
  }.freeze
end
