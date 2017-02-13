class ValidationHelper
  class << self
    def custom_validator_class_mapping
      @custom_validator_class_mapping ||= {
        custom_format: CustomFormatValidator,
        custom_absence: CustomAbsenceValidator,
        custom_inclusion: CustomInclusionValidator,
        custom_numericality: CustomNumericalityValidator,
        data_type: DataTypeValidator,
        date_time: DateTimeValidator,
        file_size: FileSizeValidator,
        required: RequiredValidator,
        string_rejection: StringRejectionValidator,
        custom_length: CustomLengthValidator,
        hash: HashValidator
      }
    end

    def default_validator_class_mapping(key)
      @default_validator_class_mapping.try(:[], key) || set_default_validator_class_mapping(key)
    end

    def set_default_validator_class_mapping(key)
      @default_validator_class_mapping ||= {}
      @default_validator_class_mapping[key] = "ActiveModel::Validations::#{key.to_s.camelize}Validator".constantize
    end

    # compute the size of attachments associated with the record.
    def attachment_size(item)
      item.try(:attachments).try(:sum, &:content_file_size).to_i
    end

  end
end
