# frozen_string_literal: true

module Channel::V2
  class ConversationSyncValidation < ::ApiValidation
    attr_accessor :meta, :user_ids, :ticket_ids, :created_at, :primary_key_offset

    validate :validate_request_params, on: :sync

    validates :meta, presence: true, on: :sync

    validates :user_ids, :ticket_ids, data_type: { rules: Array, allow_nil: false },
                                      array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false } },
                                      custom_length: { maximum: 100, minimum: 1, message_options: { element_type: :elements } }, on: :sync

    validates :created_at, data_type: { rules: Hash },
                           hash: { validatable_fields_hash: proc { |x| x.validate_time_attributes } }, on: :sync

    validates :primary_key_offset, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false }, on: :sync

    validate :validate_date_time_period, unless: -> { time_validation_errors? }, on: :sync

    def validate_time_attributes
      {
        start: { data_type: { rules: String, required: true } },
        end: { data_type: { rules: String, required: true } }
      }
    end

    def validate_request_params
      filter_attributes = Channel::V2::ConversationConstants::SYNC_FILTER_ATTRIBUTES
      errors[:require_filter_params] << :require_filter_params if (filter_attributes & @request_params.keys).blank?
      (error_options[:require_filter_params] ||= { code: :missing_field }).merge!(attributes: filter_attributes.join(', ')) if errors.present?
    end

    def time_validation_errors?
      Channel::V2::ConversationConstants::SYNC_DATETIME_ATTRIBUTES.any? { |attribute| errors[attribute].present? }
    end

    def validate_date_time_period
      Channel::V2::ConversationConstants::SYNC_DATETIME_ATTRIBUTES.each do |attribute|
        next unless @request_params[attribute]

        start_time = Time.zone.parse(@request_params[attribute]['start'])
        end_time = Time.zone.parse(@request_params[attribute]['end'])
        if start_time && end_time
          given_date_range = end_time - start_time
          errors[:"#{attribute}"] << :invalid_date_time_range if given_date_range.to_f.negative?
          errors[:"#{attribute}"] << :invalid_date_time_period if (given_date_range / 1.hour) > 48
        else
          errors[:"#{attribute}"] << :datatype_mismatch
          error_options[:"#{attribute}"] = { expected_data_type: DateTime, prepend_msg: :input_received, given_data_type: 'String' }
        end
      end
    end
  end
end
