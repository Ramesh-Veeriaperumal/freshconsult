class ContactMergeValidation < ApiValidation
  include ContactsCompaniesHelper

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
        maximum: @max_companies_count,
        message_options: { element_type: :integer }
      }
    }
  }.merge!(ContactValidation::DEFAULT_FIELD_VALIDATIONS.slice(:phone, :mobile, :twitter_id, :email, :unique_external_id)).freeze

  attr_accessor :primary_contact_id, :secondary_contact_ids, :contact, :company_ids, :phone, :mobile,
                :twitter_id, :fb_profile_id, :external_id, :email, :other_emails, :unique_external_id

  validates :primary_contact_id, required: true, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false }
  validates :secondary_contact_ids, required: true, data_type: { rules: Array, allow_nil: false }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false } }
  validates :contact, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.merge_fields } }
  validates :phone, :mobile, :twitter_id, :fb_profile_id, :external_id, :email, :other_emails, :company_ids, :unique_external_id, default_field:
                              {
                                required_fields: [],
                                field_validations: MERGE_FIELD_VALIDATIONS
                              }

  validate :validate_primary_contact_id, if: -> { errors[:primary_contact_id].blank? }

  validate :check_duplicate_companies, if: lambda {
    company_ids.present? && errors[:company_ids].blank?
  }
  validate :check_multiple_companies_feature, if: lambda {
    company_ids.present? && errors[:company_ids].blank?
  }

  validate :check_other_emails_before_removing_primary_email, if:  lambda {
    @contact_validation_params.key?(:email) && @contact_validation_params[:email].blank?
  }
  validate :check_unique_external_id_feature, if: lambda {
    unique_external_id.present? && errors[:unique_external_id].blank?
  }

  def initialize(request_params, item, _allow_string_param = false)
    super(request_params, item)
    @item = item
    @contact_validation_params = request_params[:contact] || {}
    @max_companies_count = user_companies_limit
  end

  def check_duplicate_companies
    if company_ids.length != company_ids.uniq.length
      errors[:company_ids] << :duplicate_companies
    end
  end

  def validate_primary_contact_id
    if @item.blank?
      errors[:primary_contact_id] << :invalid_primary_contact_id
    elsif @item.parent_id?
      errors[:primary_contact_id] << :merged_primary_contact_id
    elsif @item.deleted
      errors[:primary_contact_id] << :deleted_primary_contact_id
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
      company_ids: {},
      unique_external_id: {}
    }
  end

  def check_unique_external_id_feature
    unless unique_contact_identifier_enabled?
      errors[:unique_external_id] << :require_feature_for_attribute
      error_options.merge!(unique_external_id: { attribute: 'unique_external_id',
                                                 feature: :unique_contact_identifier })
    end
  end

  def check_multiple_companies_feature
    if company_ids.length > 1 && !multiple_user_companies_enabled?
      errors[:company_ids] << :require_feature_for_multiple_companies
      error_options.merge!(company_ids: { attribute: 'company_ids',
                                          feature: :multiple_user_companies })
    end
  end

  def check_other_emails_before_removing_primary_email
    if errors[:email].blank? &&
       (!@contact_validation_params.key?(:other_emails) ||
       @contact_validation_params[:other_emails].present?)
      errors[:other_emails] << :should_be_set_as_blank
      error_options.merge!(other_emails: { parent: 'Primary email' })
    end
  end

  def unique_contact_identifier_enabled?
    Account.current.unique_contact_identifier_enabled?
  end

  def multiple_user_companies_enabled?
    Account.current.multiple_user_companies_enabled?
  end
end
