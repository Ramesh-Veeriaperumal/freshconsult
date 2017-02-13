class CustomNumericalityValidator < ApiValidator
  include ErrorOptions

  NOT_A_NUMBER = 'is not a number'
  NOT_AN_INTEGER = 'is not an integer'
  MUST_BE_GREATER_THAN = 'must be greater than'
  MUST_BE_LESS_THAN = 'must be less than'

  def initialize(options = {})
    validator_options = options.dup # options would get modified and frozen in the next step.
    super(options)
    @default_validator_instance = ActiveModel::Validations::NumericalityValidator.new(validator_options)
  end

  def validate_each
    if allow_string?
      @default_validator_instance.validate_each(record, attribute, value)
      if record.errors[attribute].present?
        default_datatype_mismatch?
        record_error
      end
    else
      super
    end
  end

  def validate_each_value
    if allow_string?
      @default_validator_instance.validate_each(record, attribute, value)
      if record.errors[attribute].present?
        default_datatype_mismatch?
        record_array_field_error
      end
    else
      super
    end
  end

  private

    def skip_input_info?
      required_attribute_not_defined? || !datatype_mismatch? || array_value? || string_input_and_allow_string?
    end

    def error_code
      if required_attribute_not_defined?
        :missing_field
      elsif datatype_mismatch?
        :datatype_mismatch
      else
        :invalid_value
      end
    end

    def invalid?
      datatype_mismatch? || invalid_value?
    end

    def datatype_mismatch?
      return internal_values[:datatype_mismatch] if internal_values.key?(:datatype_mismatch)
      klass = options[:only_integer] ? Integer : Numeric
      internal_values[:datatype_mismatch] = !value.is_a?(klass)
    end

    def invalid_value?
      gt_value = options[:greater_than]
      lt_value = options[:less_than]
      (gt_value && value <= gt_value) || (lt_value && value >= lt_value)
    end

    def message
      options[:custom_message] || :datatype_mismatch
    end

    def default_datatype_mismatch?
      # numericality validator will add a error message like, "must be greater than.." if that particular constraint fails
      return internal_values[:datatype_mismatch] if internal_values.key?(:datatype_mismatch)
      error = record.errors[attribute].first
      internal_values[:datatype_mismatch] = !(error.starts_with?(MUST_BE_GREATER_THAN) || error.starts_with?(MUST_BE_LESS_THAN))
    end

    def expected_data_type
      return internal_values[:expected_data_type] if internal_values.key?(:expected_data_type)
      # it is assumed that greater_than will always mean greater_than 0, when this assumption is invalidated, we have to revisit this method
      if options[:only_integer]
        internal_values[:expected_data_type] = options[:greater_than] ? :'Positive Integer' : :Integer
      else
        internal_values[:expected_data_type] = options[:greater_than] ? :'Positive Number' : :Number
      end
    end
end
