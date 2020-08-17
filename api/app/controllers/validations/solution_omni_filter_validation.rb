# frozen_string_literal: true

class SolutionOmniFilterValidation < FilterValidation
  include SolutionHelper
  CHECK_PARAMS_SET_FIELDS = %w[portal_id tags platforms].freeze
  attr_accessor :portal_id, :platforms, :tags

  validate :validate_omni_channel_feature
  validates :portal_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }

  validate :validate_null_values
  validates :tags, data_type: { rules: Array }, array: { data_type: { rules: String },
                                                         custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING } }, if: -> { @tags.present? }

  validates :platforms, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: false },
                                                              custom_inclusion: { in: SolutionConstants::PLATFORM_TYPES } }, if: -> { @platforms.present? }

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
end
