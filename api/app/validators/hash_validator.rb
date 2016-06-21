class HashValidator < ApiValidator
  def validate_each
    valid_options = options.except(*record.class.send(:_validates_default_keys))

    value.each_pair do |attribute_key, element_value|
      valid_options.each do |key, args|
        validator_options = { attributes: attribute_key.to_sym }
        validator_options.merge!(args) if args.is_a?(Hash)
        custom_validator = ValidationHelper.custom_validator_class_mapping[key]
        validator_class = custom_validator || ValidationHelper.default_validator_class_mapping(key)
        validator = validator_class.new(validator_options)
        custom_validator ? validator.validate_value(record, element_value) : validator.validate_each(record, attribute, element_value)
      end
    end
  end

  private

    def skip_validation?
      super || !value.is_a?(Hash)
    end
end
