class CustomerImportValidation < ApiValidation
  include CustomerImportConstants

  attr_accessor :type, :file, :fields

  validates :type, required: true, custom_inclusion: {
    in: CustomerImportConstants::CUSTOMER_IMPORT_TYPES, allow_nil: false
  }
  validates :fields, data_type: { rules: Hash, allow_nil: false },
                     required: true
  validates :file, required: true
  validates_each :file, on: :create do |record, attr, value|
    if value && !CSV_FILE_EXTENSION_REGEX.match(value.original_filename)
      record.errors.add(attr,
          ErrorConstants::ERROR_MESSAGES[:invalid_format] % ACCEPTED_FILE_TYPE)
    end
  end
end
