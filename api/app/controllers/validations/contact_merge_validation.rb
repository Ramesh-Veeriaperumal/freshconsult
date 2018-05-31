class ContactMergeValidation < ApiValidation
  MERGE_FIELD_VALIDATIONS = {
    fb_profile_id: { data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } },
    external_id: { data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } },
    other_emails: {
      data_type: { rules: Array },
      array: {
        custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' },
        custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
      },
      custom_length: {
        maximum: ContactConstants::MAX_OTHER_EMAILS_COUNT,
        message_options: { element_type: :values }
      }
    },
    company_ids: {
      data_type: { rules: Array },
      array: {
        custom_numericality: {
          greater_than: 0,
          only_integer: true
        },
        allow_nil: false
      },
      custom_length: {
        maximum: User::MAX_USER_COMPANIES,
        message_options: { element_type: :integer }
      }
    }
  }.merge!(ContactValidation::DEFAULT_FIELD_VALIDATIONS.slice(:phone, :mobile, :twitter_id, :email)).freeze

  attr_accessor :primary_id, :target_ids, :contact, :company_ids, :phone, :mobile,
                :twitter_id, :fb_profile_id, :external_id, :email, :other_emails

  validates :primary_id, required: true, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false }
  validates :target_ids, required: true, data_type: { rules: Array, allow_nil: false }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false } }
  validates :contact, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.merge_fields } }
  validates :phone, :mobile, :twitter_id, :fb_profile_id, :external_id, :email, :other_emails, :company_ids, default_field:
                              {
                                required_fields: [],
                                field_validations: MERGE_FIELD_VALIDATIONS
                              }

  validate :check_duplicate_companies, if: lambda {
    company_ids.present? && errors[:company_ids].blank?
  }

  def initialize(request_params, item, _allow_string_param = false)
    super(request_params, item)
    contact_validation_params = request_params[:contact]
    field = ContactConstants::MERGE_CONTACT_FIELDS
    contact_validation_params.try(:permit, *field)
  end

  def check_duplicate_companies
    if company_ids.length != company_ids.uniq.length
      errors[:company_ids] << :duplicate_companies
    end
  end

  def merge_fields
    {
      phone: {},
      mobile: {},
      twitter_id: {},
      fb_profile_id: {},
      external_id: {},
      other_emails: {},
      company_ids: {}
    }
  end

end
