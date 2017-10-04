module OnboardingConstants
  LOAD_OBJECTS_EXCEPT = [:update_channel_config].freeze
  UPDATE_ACTIVATION_EMAIL_FIELDS = [:new_email].freeze
  UPDATE_CHANNEL_CONFIG_FIELDS = [:channels].freeze
  CHANNELS = %w(phone live_chat social forums).freeze
  DISABLEABLE_CHANNELS = %w(social forums).freeze
  VALIDATION_CLASS = 'OnboardingValidation'.freeze
end.freeze
