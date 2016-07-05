class ArrayValidator < ApiValidator
  def validate_each
    valid_options = options.except(*record.class.send(:_validates_default_keys))

    value.each do |element_value|
      valid_options.each do |key, args|
        return if record.errors[attribute].present?
        validator_options = { attributes: attribute }
        validator_options.merge!(args) if args.is_a?(Hash)
        custom_validator = ValidationHelper.custom_validator_class_mapping[key]
        validator_class = custom_validator || ValidationHelper.default_validator_class_mapping(key)
        validator = validator_class.new(validator_options)
        # when default validators are nested inside array validator, allow_nil & allow_blank options of those will be ignored.
        # because we are not calling validate on the validator instance & validate method handles skipping validation logic.
        # But this is not an issue as nil and blank values are rejected from array before doing validation.
        custom_validator ? validator.validate_value(record, element_value) : validator.validate_each(record, attribute, element_value)
      end
    end
  end

  private

    def skip_validation?
      super || !value.is_a?(Array)
    end
end
