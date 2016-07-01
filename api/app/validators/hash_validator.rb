class HashValidator < ApiValidator
  def validate_each
    validate_hash
  end

  def validate_each_value
    validate_hash
  end

  def validate_hash
    valid_options = options.except(*record.class.send(:_validates_default_keys))
    valid_options = call_block(delimeter)
    valid_options.keys.each do |nested_field|
      validations = valid_options[nested_field]
      validations.each do |key, args|
        validator_options = { attributes: nested_field, nested_field: "#{attribute}.#{nested_field}" }
        validator_options.merge!(args) if args.is_a?(Hash)
        custom_validator = ValidationHelper.custom_validator_class_mapping[key]
        if custom_validator
          validator = custom_validator.new(validator_options)
          element_value = value.fetch(nested_field, ApiConstants::VALUE_NOT_DEFINED)
          validator.validate_value(record, element_value)
        else
          fail DefaultValidatorNotImplementedError, 'API Validators are developed to provide enhanced error messages and custom_codes to the users for clear understanding. Validations that are possible in default validators can be achieved using the API Validators, as a result API Validators wont support the default ones. Please extend if you have such requirement.'
        end
      end
    end
  end

  def delimeter
    options[:validatable_fields_hash]
  end

  private

    def skip_validation?
      super || !value.is_a?(Hash)
    end
end
