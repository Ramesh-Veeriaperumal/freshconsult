class OnboardingValidation < ApiValidation
  attr_accessor :new_email, :channel, :attempt, :send_to, :admin_email, :requested_time

  validates :new_email, presence: true, on: :update_activation_email
  validates :new_email, data_type: { rules: String }, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }, on: :update_activation_email
  validates :channel, required: true, data_type: { rules: String }, custom_inclusion: { in: OnboardingConstants::CHANNELS }, on: :update_channel_config
  validates :attempt, required: true, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: OnboardingConstants::TEST_FORWARDING_ATTEMPT_THRESHOLD, required: true }, on: :test_email_forwarding
  validates :send_to, required: true, data_type: { rules: String }, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }, on: :test_email_forwarding
  validates :admin_email, presence: true,
                          data_type: { rules: String },
                          custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' },
                          custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }, on: :anonymous_to_trial
  validates :requested_time, date_time: { allow_nil: true }, required: true, data_type: { rules: String }, on: :forward_email_confirmation

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end
end
