module Freshquery
  module Validators
    class BaseValidator < ActiveModel::EachValidator
      attr_reader :record, :attribute, :value, :internal_values

      def validate_value(record, value)
        @record = record
        attributes.each do |attribute|
          next if value.nil?
          @internal_values = { }
          @attribute = attribute
          @value = value
          record.error_options[attribute] ||= {}
          validate_each_value
        end
      end

      def validate_each_value
        record_error if invalid?
      end

      private

        def call_block(block)
          block.respond_to?(:call) ? block.call(record) : block
        end

        def record_error
          record.errors[attribute] << (options[:message] || message)
          record.error_options[attribute] = custom_error_options.merge!(base_error_options)
        end

        def base_error_options
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
    end
  end
end