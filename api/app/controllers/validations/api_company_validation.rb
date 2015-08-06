class ApiCompanyValidation < ApiValidation
  attr_accessor :name, :description, :domains, :note, :custom_fields, :custom_field_types
  validates :name, required: true
  validates :custom_fields, data_type: { rules: Hash }, custom_field: { custom_field_type: proc { custom_field_types } }, allow_nil: true
  validates :name, :description, :note, data_type: { rules: String, allow_nil: true }
  validates :domains, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: String, allow_nil: true } }
  validates :custom_fields, custom_field: {
    validatable_custom_fields: proc { Helpers::CompaniesValidationHelper.custom_company_fields }
  }, allow_nil: true

  def initialize(request_params, item, _company_fields)
    super(request_params, item)
  end
end
