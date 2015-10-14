class ApiCompanyValidation < ApiValidation
  attr_accessor :name, :description, :domains, :note, :custom_fields, :custom_field_types
  validates :description, :domains, :note, default_field: 
                              { 
                                required_fields: proc { |x| x.required_default_fields },
                                field_validations: CompanyConstants::DEFAULT_FIELD_VALIDATIONS
                              } 
  validates :name, required: true, data_type: { rules: String }
  validates :name, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }, if: -> { errors[:name].blank? } 
  
  # Shouldn't be clubbed as allow nil may have some impact on custom fields validator.
  validates :custom_fields, data_type: { rules: Hash, allow_nil: true }
  validates :custom_fields, custom_field: { custom_fields: {
    validatable_custom_fields: proc { Helpers::CompaniesValidationHelper.data_type_validatable_custom_fields },
    required_attribute: :required_for_agent
  }
  }

  def initialize(request_params, item)
    super(request_params, item)
    @domains = request_params[:domains] if request_params.key?(:domains) || item
  end

  def attributes_to_be_stripped
    CompanyConstants::FIELDS_TO_BE_STRIPPED
  end

  def required_default_fields
    Account.current.company_form.default_company_fields.select{ |x| x.required_for_agent  }
  end
end
