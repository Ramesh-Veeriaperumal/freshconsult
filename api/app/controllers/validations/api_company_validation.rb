class ApiCompanyValidation < ApiValidation
  attr_accessor :name, :description, :domains, :note, :custom_fields, :custom_field_types
  validates :name, required: true
  validates :name, :description, :note, data_type: { rules: String, allow_nil: true }
  validates :domains, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: String, allow_nil: true } }
  validates :custom_fields, custom_field: { custom_fields: {
    validatable_custom_fields: proc { Helpers::CompaniesValidationHelper.data_type_validatable_custom_fields },
    required_attribute: :required_for_agent
  }
  }
end
