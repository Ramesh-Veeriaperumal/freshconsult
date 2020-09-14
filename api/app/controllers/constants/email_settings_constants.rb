module EmailSettingsConstants
  VALIDATION_CLASS = 'Email::SettingsValidation'.freeze
  email_settings = %w[personalized_email_replies create_requester_using_reply_to allow_agent_to_initiate_conversation original_sender_as_requester_for_forward]
  UPDATE_FIELDS = Account.current.email_new_settings_enabled? ? email_settings.freeze : (email_settings + %w[allow_wildcard_ticket_create skip_ticket_threading]).freeze
  COMPOSE_EMAIL_FEATURE = :compose_email
  DISABLE_AGENT_FORWARD = :disable_agent_forward
  EMAIL_CONFIG_PARAMS = {
    create_requester_using_reply_to: :reply_to_based_tickets,
    original_sender_as_requester_for_forward: :disable_agent_forward,
    allow_agent_to_initiate_conversation: :compose_email,
    personalized_email_replies: :personalized_email_replies
  }.freeze
end
