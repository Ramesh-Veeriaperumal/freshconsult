class ApiCompanyValidation < ApiValidation
  attr_accessor :name, :description, :domains, :note, :custom_fields, :custom_field_types
  validates :name, required: true, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }
  validates :name, :description, :note, data_type: { rules: String, allow_nil: true }
  validates :domains, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: String, allow_nil: true } }
  validates :domains, string_rejection: { excluded_chars: [','] }
  validates :custom_fields, data_type: { rules: Hash, allow_nil: true }
  validates :custom_fields, custom_field: { custom_fields: {
    validatable_custom_fields: proc { Helpers::CompaniesValidationHelper.data_type_validatable_custom_fields },
    required_attribute: :required_for_agent
  }
  }

  def initialize(request_params, item)
    super(request_params, item)
    @domains = request_params[:domains]
  end

  def attributes_to_be_stripped
    CompanyConstants::FIELDS_TO_BE_STRIPPED
  end
end
