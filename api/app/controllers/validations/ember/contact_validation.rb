class Ember::ContactValidation < ContactValidation
  attr_accessor :company, :facebook_id

  MANDATORY_FIELDS = [:email, :mobile, :phone, :twitter_id, :unique_external_id, :facebook_id].freeze

  alias_attribute :company, :company_name

  validates :other_companies, data_type: { rules: Array }, array: {
    data_type: { rules: Hash },
    allow_nil: true,
    hash: -> { other_companies_format }
  }
  validates :facebook_id, data_type: { rules: String, allow_nil: true },
                          custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  def initialize(request_params, item, allow_string_param = false, enforce_mandatory = 'true')
    self.skip_hash_params_set_for_parameters = ['company']
    super(request_params, item, allow_string_param, enforce_mandatory)
    company_hash_validation = {
      company_name: {
        data_type: { rules: Hash },
        hash: { validatable_fields_hash: proc { |x| x.company_hash_structure } }
      }
    }
    DEFAULT_FIELD_VALIDATIONS.merge!(company_hash_validation) unless \
      [:quick_create, :requester_update, :update_password].include?(@action.try(:to_sym))
  end

  def company_hash_structure
    {
      id: {
        custom_numericality: {
          greater_than: 0,
          only_integer: true
        }
      },
      name: {
        data_type: { rules: String },
        custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
      },
      view_all_tickets: {
        data_type: {
          rules: 'Boolean',
          ignore_string: :allow_string_param,
          allow_nil: true
        }
      }
    }
  end

  def check_duplicates_multiple_companies
    ids = other_companies.collect { |x| x[:id] }.compact
    if company && ids.any? { |id| id == company[:id] }
      errors[:other_companies] << :cant_add_primary_resource_to_others
      self.error_options.merge!(other_companies: {
                                  resource: company[:id].to_s,
                                  status: 'default company',
                                  attribute: 'other_companies'
                                })
    elsif ids.length != ids.uniq.length
      errors[:other_companies] << :duplicate_companies
    end
  end

  def check_for_default_company_before_adding_other_companies
    other_companies && !other_companies.empty? && company.blank?
  end

  def other_companies_format
    {
      id: {
        custom_numericality: {
          ignore_string: :allow_string_param,
          greater_than: 0,
          only_integer: true,
          allow_nil: true
        }
      },
      name: {
        data_type: { rules: String, required: true },
        custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
      },
      view_all_tickets: {
        data_type: {
          rules: 'Boolean',
          ignore_string: :allow_string_param
        }
      }
    }
  end

  def view_all_tickets_present?
    false
  end

  def email_mandatory?
    MANDATORY_FIELDS.all? { |x| safe_send(x).blank? && errors[x].blank? }
  end

  def mandatory_field_array
    if unique_contact_identifier_enabled?
      MANDATORY_FIELDS
    else
      MANDATORY_FIELDS - [:unique_external_id]
    end
  end
end
