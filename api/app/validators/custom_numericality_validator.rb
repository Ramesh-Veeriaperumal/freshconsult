class CustomNumericalityValidator < ActiveModel::Validations::NumericalityValidator
  NOT_A_NUMBER = 'is not a number'
  NOT_AN_INTEGER = 'is not an integer'
  MUST_BE_GREATER_THAN = 'must be greater than'
  MUST_BE_LESS_THAN = 'must be less than'

  def validate_each(record, attribute, value)
    return if record.errors[attribute].present?

    message = options[:message]

    # if ignore_string is present and true, proceed with numericality validator.
    # else fall back to custom numericality which will not allow numbers in string representation say "1".
    if !options[:ignore_string].nil? && record.send(options[:ignore_string])
      super(record, attribute, value)
    else
      validate_numeric(record, attribute, value, message)
    end

    if record.errors[attribute].present?
      if message
        record.errors[attribute] = message
      else
        # if message is sent, it is not possible to distinguish between datatype_mismatch and invalid_value in custom_code,
        # custom message has to either be handled in controller(eg. per_page) or should use single custom_code(eg. array numericality)
        record.errors[attribute] = error_msg(record, attribute, value)
      end
      (record.error_options ||= {}).merge!(attribute => { data_type: data_type(options[:greater_than], options[:only_integer]) })
    end
  end

  private

    def validate_numeric(record, attribute, value, _message)
      if options[:only_integer]
        record.errors[attribute] = NOT_AN_INTEGER and return unless value.is_a?(Integer)
      else
        record.errors[attribute] = NOT_A_NUMBER and return unless value.is_a?(Numeric) # not using Kernel.Float as Rails does as exception handling has to be done. Have to investigate further when an actual usecase arises.
      end

      if gt_value = options[:greater_than]
        record.errors[attribute] = MUST_BE_GREATER_THAN and return if (value <= gt_value)
      end

      if lt_value = options[:less_than]
        record.errors[attribute] = MUST_BE_LESS_THAN and return if (value >= lt_value)
      end
    end

    def invalid_value_error(record, attribute)
      # numericality validator will add a error message like, "must be greater than.." if that particular constraint fails
      record.errors[attribute].first.starts_with?(MUST_BE_GREATER_THAN) || record.errors[attribute].first.starts_with?(MUST_BE_LESS_THAN)
    end

    def error_msg(record, attribute, value)
      required = required_attribute_not_defined?(record, attribute, value)
      if invalid_value_error(record, attribute)
        record.errors[attribute] = required ? :required_and_invalid_number : :invalid_number
      else # numericality validator will add a error message like, is not a number (or) must be an integer
        record.errors[attribute] = required ? :required_and_data_type_mismatch : :data_type_mismatch
      end
    end

    def data_type(greater_than, only_integer)
      # it is assumed that greater_than will always mean greater_than 0, when this assumption is invalidated, we have to revisit this method
      if only_integer
        greater_than ? :'Positive Integer' : :Integer
      else
        greater_than ? :'Positive Number' : :Number
      end
    end

    def required_attribute_not_defined?(record, attribute, _value)
      options[:required] && !record.instance_variable_defined?("@#{attribute}")
    end
end
