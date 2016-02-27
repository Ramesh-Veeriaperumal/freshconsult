class ArrayValidator < ApiValidator

  def validate_each
    valid_options = options.except(*record.class.send(:_validates_default_keys))
    
    value.each do |element_value|
      valid_options.each do |key, args|
        return if record.errors[attribute].present?
        validator_options = { attributes: attribute }
        validator_options.merge!(args) if Hash === args
        custom_validator = self.class.custom_validator_class_mapping[key]
        validator_class = custom_validator || "ActiveModel::Validations::#{key.to_s.camelize}Validator".constantize
        validator = validator_class.new(validator_options)
        custom_validator ? validator.validate_value(record, element_value) : validator.validate_each(record, attribute, element_value)
      end
    end
  end

  private

    def skip_validation?
      super || !(Array === value)
    end

    def self.custom_validator_class_mapping
        {
          custom_format: CustomFormatValidator,
          custom_absence: CustomAbsenceValidator,
          custom_inclusion: CustomInclusionValidator,
          custom_numericality: CustomNumericalityValidator,
          data_type: DataTypeValidator,
          date_time: DateTimeValidator,
          file_size: FileSizeValidator,
          required: RequiredValidator,
          string_rejection: StringRejectionValidator 
        }
    end
end
