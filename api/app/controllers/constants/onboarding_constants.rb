module OnboardingConstants
  LOAD_OBJECTS_EXCEPT = [:update_channel_config, :forward_email_confirmation].freeze
  UPDATE_ACTIVATION_EMAIL_FIELDS = [:new_email].freeze
  UPDATE_CHANNEL_CONFIG_FIELDS = [:channel].freeze
  TEST_EMAIL_FORWARDING_FIELDS = [:attempt, :send_to].freeze
  CHANNELS = %w[phone freshchat social forums].freeze
  DISABLEABLE_CHANNELS = %w[social forums].freeze
  ANONYMOUS_TO_TRIAL_FIELDS = %(admin_email).freeze
  VALIDATION_CLASS = 'OnboardingValidation'.freeze
  DELEGATOR_CLASS = 'OnboardingDelegator'.freeze
  TICKET_CREATE_DURATION = 5.minutes
  VALID_EMAIL_PROVIDERS = ::ONBOARDING_CONFIG['email_forwarding']['email_providers'].freeze
  FROM_EMAIL = ::ONBOARDING_CONFIG['email_forwarding']['from_email'].freeze
  CONFIRMATION_REGEX = ::ONBOARDING_CONFIG['email_forwarding']['confirmation_regex'].freeze
  TEST_FORWARDING_ATTEMPT_THRESHOLD = 6
  TEST_FORWARDING_SUBJECT = 'Woohoo.. Your Freshdesk Test Mail'.freeze
  FRESHCHAT = 'freshchat'.freeze
  FRESHCALLER = 'phone'.freeze
  ACCOUNT_CREATION_CHANNELS = %w[phone freshchat].freeze
  FRESHCHAT_ALREADY_LOGIN = 'ERR_ALREADY_LOGGED_IN'.freeze
  FRESHCHAT_ACCOUNT_PRESENT = 'ERR_LOGIN_TO_SIGNUP'.freeze
end.freeze
