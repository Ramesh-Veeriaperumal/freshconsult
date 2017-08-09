class CustomerImportValidation < ApiValidation
  include CustomerImportConstants

  attr_accessor :type, :file, :fields
  
  validates :type, required: true, custom_inclusion: { 
              in: CustomerImportConstants::CUSTOMER_IMPORT_TYPES, allow_nil: false }
  validates :fields, data_type: { rules: Hash, allow_nil: false }, 
              required: true
  validates :file, required: true
  validates_each :file, on: :create do |record, attr, value|
  	record.errors.add(attr, 
      ErrorConstants::ERROR_MESSAGES[:invalid_format]%ACCEPTED_FILE_TYPE) if value && value.content_type != CSV_CONTENT_TYPE
  end
  
end