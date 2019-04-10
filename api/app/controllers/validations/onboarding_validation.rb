class OnboardingValidation < ApiValidation
  attr_accessor :new_email, :channels, :attempt, :send_to, :admin_email

  validates :new_email, presence: true, on: :update_activation_email
  validates :new_email, data_type: { rules: String }, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }, on: :update_activation_email
  validates :channels, data_type: { rules: Array }, array: { custom_inclusion: { in: OnboardingConstants::CHANNELS } }, on: :update_channel_config
  validates :attempt, required: true, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: OnboardingConstants::TEST_FORWARDING_ATTEMPT_THRESHOLD, required: true }, on: :test_email_forwarding
  validates :send_to, required: true, data_type: { rules: String }, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }, on: :test_email_forwarding
  validates :admin_email, presence: true,
                          data_type: { rules: String },
                          custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' },
                          custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }, on: :anonymous_to_trial

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end
end
