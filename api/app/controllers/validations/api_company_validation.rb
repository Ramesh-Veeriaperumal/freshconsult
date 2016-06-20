class ApiCompanyValidation < ApiValidation
  DEFAULT_FIELD_VALIDATIONS = {
    description:  { data_type: { rules: String } },
    note: { data_type: { rules: String } },
    domains:  { data_type: { rules: Array, allow_nil: false }, array: { data_type: { rules: String } }, string_rejection: { excluded_chars: [','], allow_nil: true } }
  }.freeze
  CHECK_PARAMS_SET_FIELDS = %w(custom_fields).freeze

  attr_accessor :name, :description, :domains, :note, :custom_fields, :custom_field_types
  validates :description, :domains, :note, default_field:
                              {
                                required_fields: proc { |x| x.required_default_fields },
                                field_validations: DEFAULT_FIELD_VALIDATIONS
                              }
  validates :name, data_type: { rules: String, required: true }
  validates :name, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }

  # Shouldn't be clubbed as allow nil may have some impact on custom fields validator.
  validates :custom_fields, data_type: { rules: Hash }
  validates :custom_fields, custom_field: { custom_fields: {
    validatable_custom_fields: proc { Account.current.company_form.custom_non_dropdown_fields },
    required_attribute: :required_for_agent
  }
  }

  def initialize(request_params, item)
    super(request_params, item)
    @domains = item.domains.to_s.split(',') if item && !request_params.key?(:domains)
    fill_custom_fields(request_params, item.custom_field) if item && item.custom_field.present?
  end

  def attributes_to_be_stripped
    CompanyConstants::ATTRIBUTES_TO_BE_STRIPPED
  end

  def required_default_fields
    Account.current.company_form.default_company_fields.select(&:required_for_agent)
  end
end
