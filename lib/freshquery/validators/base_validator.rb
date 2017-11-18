module Freshquery
  module Validators
    class BaseValidator < ActiveModel::EachValidator
      ARRAY_MESSAGE_MAP = {
        datatype_mismatch: :array_datatype_mismatch,
        too_long: :array_too_long,
        invalid_format: :array_invalid_format
      }

      attr_reader :record, :attribute, :value, :internal_values

      def validate_value(record, value)
        @record = record
        attributes.each do |attribute|
          next if value.nil?
          @internal_values = { array: true }
          @attribute = attribute
          @value = value
          record.error_options[attribute] ||= {}
          validate_each_value
        end
      end

      def validate_each_value
        record_array_field_error if invalid?
      end

      private

        def attribute_defined?
          @value != ApiConstants::VALUE_NOT_DEFINED && record.instance_variable_defined?("@#{attribute}")
        end

        def call_block(block)
          block.respond_to?(:call) ? block.call(record) : block
        end

        def record_array_field_error
          record.errors[attribute] << (options[:message] || message)
          record.error_options[attribute] = custom_error_options.merge!(base_error_options)
        end

        # used by boolean validator
        def present_or_false?
          value.present? || value.is_a?(FalseClass)
        end

        def base_error_options
          # error_options = (options[:message_options] ? options[:message_options].dup : {})
          error_options = {}
          code = options[:code] || error_code
          error_options.merge!(code: code) if code
          error_options
        end

        def custom_error_options
          {}
        end

        def error_code
          # set code here to override the deault code assignment that would happen using ErrorConstants::API_ERROR_CODES_BY_VALUE
        end

        def message
          # the error message that should be added if the record is invalid.
        end

        def invalid?
          # condition that determines the validity of the record.
        end

        # Used by boolean validator
        def array_value?
          internal_values[:array]
        end
    end
  end
end