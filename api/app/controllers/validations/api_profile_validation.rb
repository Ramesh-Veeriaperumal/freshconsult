class ApiProfileValidation < ApiValidation
  attr_accessor :time_zone, :language, :signature, :job_title, :id, :shortcuts_enabled

  CHECK_PARAMS_SET_FIELDS = %w(time_zone language signature job_title shortcuts_enabled).freeze

  validates :job_title, data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :language, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field,  message_options: { attribute: 'language', feature: :multi_language } }, unless: :multi_language_enabled?
  validates :time_zone, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field, message_options: { attribute: 'time_zone', feature: :multi_timezone } }, unless: :multi_timezone_enabled?
  validates :language, custom_inclusion: { in: ContactConstants::LANGUAGES }
  validates :time_zone, custom_inclusion: { in: ContactConstants::TIMEZONES }
  validates :signature, data_type: { rules: String, allow_nil: true }
  validates :shortcuts_enabled, data_type: { rules: 'Boolean' }
  
  def initialize(request_params, item, allow_string_param = false)
    if item
      user = item.user
      super(request_params, user, allow_string_param)
    else
      super(request_params, nil, allow_string_param)
    end
  end

  def multi_language_enabled?
    Account.current.features?(:multi_language)
  end

  def multi_timezone_enabled?
    Account.current.multi_timezone_enabled?
  end
end