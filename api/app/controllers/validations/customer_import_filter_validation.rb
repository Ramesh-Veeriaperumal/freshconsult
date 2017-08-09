class CustomerImportFilterValidation < FilterValidation
  include CustomerImportConstants
  attr_accessor :type
  
  validates :type, required: true, custom_inclusion: { in: CUSTOMER_IMPORT_TYPES, allow_nil: false }
  
end