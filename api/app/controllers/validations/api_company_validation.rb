class ApiCompanyValidation < ApiValidation
  DEFAULT_FIELD_VALIDATIONS = {
    description:  { data_type: { rules: String } },
    note: { data_type: { rules: String } },
    domains:  { data_type: { rules: Array, allow_nil: false }, array: { data_type: { rules: String } }, string_rejection: { excluded_chars: [','], allow_nil: true } },
    health_score:  { data_type: { rules: String } },
    account_tier:  { data_type: { rules: String } },
    industry:  { data_type: { rules: String } },
    renewal_date: { date_time: { only_date: true } }
  }.freeze
  CHECK_PARAMS_SET_FIELDS = %w(custom_fields health_score account_tier industry renewal_date).freeze

  attr_accessor :name, :description, :domains, :note, :custom_fields, :custom_field_types,
                :health_score, :account_tier, :industry, :renewal_date
  validates :name, data_type: { rules: String, required: true }
  validates :name, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :health_score, custom_absence: 
                             { message: :require_feature_for_attribute,
                               code: :inaccessible_field,
                               message_options: {
                                 attribute: 'health_score',
                                 feature: :tam_default_fields } }, 
                            unless: :tam_default_fields_enabled?

  validates :account_tier, custom_absence: 
                             { message: :require_feature_for_attribute,
                               code: :inaccessible_field,
                               message_options: {
                                 attribute: 'account_tier',
                                 feature: :tam_default_fields } }, 
                            unless: :tam_default_fields_enabled?

  validates :industry, custom_absence: 
                             { message: :require_feature_for_attribute,
                               code: :inaccessible_field,
                               message_options: {
                                 attribute: 'industry',
                                 feature: :tam_default_fields } }, 
                            unless: :tam_default_fields_enabled?

  validates :renewal_date, custom_absence: 
                             { message: :require_feature_for_attribute,
                               code: :inaccessible_field,
                               message_options: {
                                 attribute: 'renewal_date',
                                 feature: :tam_default_fields } }, 
                            unless: :tam_default_fields_enabled?


  validates :description, :domains, :note, :health_score,
            :account_tier, :industry, :renewal_date,
            default_field: {
              required_fields: proc { |x| x.required_default_fields },
              field_validations: DEFAULT_FIELD_VALIDATIONS
            }

  # Shouldn't be clubbed as allow nil may have some impact on custom fields validator.
  validates :custom_fields, data_type: { rules: Hash }
  validates :custom_fields, custom_field: { custom_fields: {
    validatable_custom_fields: proc { Account.current.company_form.custom_non_dropdown_fields },
    required_attribute: :required_for_agent
  }
  }, unless: -> { validation_context == :channel_company_create }
  validates :custom_fields, custom_field: { custom_fields: {
    validatable_custom_fields: proc { Account.current.company_form.custom_non_dropdown_fields }
  }
  }, if: -> { validation_context == :channel_company_create }

  def initialize(request_params, item)
    super(request_params, item)
    @domains = item.domains.to_s.split(',') if item && !request_params.key?(:domains)
    fill_tam_fields(item, request_params) if item
    fill_custom_fields(request_params, item.custom_field) if item && item.custom_field.present?
  end

  def attributes_to_be_stripped
    CompanyConstants::ATTRIBUTES_TO_BE_STRIPPED
  end

  def required_default_fields
    validation_context == :channel_company_create ? [] : Account.current.contact_form.default_contact_fields.select(&:required_for_agent)
  end

  private

    def fill_tam_fields(item, request_params)
      @health_score = item.health_score unless request_params.key?(:health_score)
      @account_tier = item.account_tier unless request_params.key?(:account_tier)
      @industry     = item.industry unless request_params.key?(:industry)
      @renewal_date = item.renewal_date unless request_params.key?(:renewal_date)
    end

    def tam_default_fields_enabled?
      Account.current.tam_default_fields_enabled?
    end
end
