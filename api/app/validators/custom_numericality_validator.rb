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
    if (!options[:ignore_string].nil? && record.send(options[:ignore_string])) || options[:force_allow_string]
      @default_validator_instance.validate_each(record, attribute, value)
      if record.errors[attribute].present?
        default_data_type_mismatch?
        record_error
      end
    else
      super
    end
  end

  private

    def error_options
      error_options = { expected_data_type: expected_data_type }
      error_options.merge!(prepend_msg: :input_received, given_data_type: infer_data_type(value)) unless skip_input_info?
      error_options
    end

    def skip_input_info?
      required_attribute_not_defined? || !values[:data_type_mismatch] || values[:array]
    end

    def error_code
      if values[:req_attr_ndef]
        :missing_field
      else
        :invalid_value unless values[:data_type_mismatch]
      end
    end

    def invalid?
      data_type_mismatch? || invalid_value?
    end

    def data_type_mismatch?
      klass = options[:only_integer] ? Integer : Numeric
      values[:data_type_mismatch] = !(klass === value)
    end

    def invalid_value?
      gt_value = options[:greater_than]
      lt_value = options[:less_than]
      (gt_value && value <= gt_value) || (lt_value && value >= lt_value)
    end

    def message
      options[:custom_message] || :data_type_mismatch
    end

    def default_data_type_mismatch?
      # numericality validator will add a error message like, "must be greater than.." if that particular constraint fails
      error = record.errors[attribute].first
      values[:data_type_mismatch] = !(error.starts_with?(MUST_BE_GREATER_THAN) || error.starts_with?(MUST_BE_LESS_THAN))
    end

    def expected_data_type
      # it is assumed that greater_than will always mean greater_than 0, when this assumption is invalidated, we have to revisit this method
      if options[:only_integer]
        options[:greater_than] ? :'Positive Integer' : :Integer
      else
        options[:greater_than] ? :'Positive Number' : :Number
      end
    end
end
