module Freshquery
  module Validators
    class CustomNumericalityValidator < BaseValidator
      NOT_A_NUMBER = 'is not a number'
      NOT_AN_INTEGER = 'is not an integer'
      MUST_BE_GREATER_THAN = 'must be greater than'
      MUST_BE_LESS_THAN = 'must be less than'

      def initialize(options = {})
        super(options)
      end

      def validate_each_value
        super
      end

      private

        def error_code
          datatype_mismatch? ? :datatype_mismatch : :invalid_value
        end

        def invalid?
          datatype_mismatch? || invalid_value?
        end

        def datatype_mismatch?
          return internal_values[:datatype_mismatch] if internal_values.key?(:datatype_mismatch)
          internal_values[:datatype_mismatch] = !value.is_a?(Integer)
        end

        def invalid_value?
          gt_value = options[:greater_than]
          lt_value = options[:less_than]
          (gt_value && value <= gt_value) || (lt_value && value >= lt_value)
        end

        def message
          "It should be a/an #{expected_data_type}"
        end

        # def default_datatype_mismatch?
        #   # numericality validator will add a error message like, "must be greater than.." if that particular constraint fails
        #   return internal_values[:datatype_mismatch] if internal_values.key?(:datatype_mismatch)
        #   error = record.errors[attribute].first
        #   internal_values[:datatype_mismatch] = !(error.starts_with?(MUST_BE_GREATER_THAN) || error.starts_with?(MUST_BE_LESS_THAN))
        # end

        # def custom_error_options
        #   { expected_data_type: expected_data_type}
        # end

        def expected_data_type
          return internal_values[:expected_data_type] if internal_values.key?(:expected_data_type)
          # it is assumed that greater_than will always mean greater_than 0, when this assumption is invalidated, we have to revisit this method
          internal_values[:expected_data_type] = options[:greater_than] ? :'Positive Integer' : :Integer
        end
    end
  end
end