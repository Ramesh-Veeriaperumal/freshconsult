# frozen_string_literal: true

class SolutionOmniFilterValidation < FilterValidation
  include SolutionHelper

  CHECK_PARAMS_SET_FIELDS = %w[portal_id tags platforms status prefer_published].freeze
  attr_accessor :portal_id, :platforms, :tags, :status, :prefer_published, :allow_language_fallback

  validate :validate_omni_channel_feature
  validates :portal_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }

  validate :validate_null_values
  validates :tags, data_type: { rules: Array }, array: { data_type: { rules: String },
                                                         custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING } }, if: -> { @tags.present? }

  validates :platforms, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: false },
                                                              custom_inclusion: { in: SolutionConstants::PLATFORM_TYPES } }, if: -> { @platforms.present? }

  validates :allow_language_fallback, custom_inclusion: { in: [true, false], ignore_string: :allow_string_param }, if: -> { @allow_language_fallback.present? }
  validates :status, custom_inclusion: { in: proc { |x| x.allowed_statuses }, ignore_string: :allow_string_param }

  validates :prefer_published, data_type: { rules: 'Boolean' }

  def initialize(request_params, item = nil, allow_string_param = true)
    super(request_params, item, allow_string_param)
  end

  def validate_omni_channel_feature
    unless allow_chat_platform_attributes?
      omni_channel_error(:platforms) if @request_params.key?(:platforms)
      omni_channel_error(:tags) if @request_params.key?(:tags)
    end
    errors.blank?
  end

  def omni_channel_error(field)
    errors[field] << :require_feature
    error_options[field] = { feature: :omni_bundle_2020, code: :access_denied }
  end

  def validate_null_values
    check_null_value(:tags)
    check_null_value(:platforms)
  end

  def check_null_value(field)
    null_value_error(field) if @request_params.key?(field) && @request_params[field].blank? && errors[field].blank?
  end

  def null_value_error(field)
    errors[field] << :comma_separated_values
    error_options[field] = { prepend_msg: :input_received, given_data_type: DataTypeValidator::DATA_TYPE_MAPPING[NilClass] }
  end

  def allowed_statuses
    [SolutionConstants::STATUS_FILTER_BY_TOKEN[:draft], SolutionConstants::STATUS_FILTER_BY_TOKEN[:published]]
  end
end
