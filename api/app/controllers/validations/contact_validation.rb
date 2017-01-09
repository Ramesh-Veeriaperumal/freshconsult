class ContactValidation < ApiValidation
  DEFAULT_FIELD_VALIDATIONS = {
    job_title:  { data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } },
    language: { custom_inclusion: { in: ContactConstants::LANGUAGES } },
    time_zone: { custom_inclusion: { in: ContactConstants::TIMEZONES } },
    phone: { data_type: { rules: String },  custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } },
    mobile: { data_type: { rules: String },  custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } },
    address: { data_type: { rules: String },  custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } },
    twitter_id: { data_type: { rules: String },  custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } },
    email: { data_type: { rules: String }, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } },
    description: { data_type: { rules: String } },
    company_name: {
      custom_numericality: {
        ignore_string: :allow_string_param,
        greater_than: 0,
        only_integer: true
      }
    }
  }.freeze

  MANDATORY_FIELD_ARRAY = [:email, :mobile, :phone, :twitter_id].freeze
  CHECK_PARAMS_SET_FIELDS = ( MANDATORY_FIELD_ARRAY.map(&:to_s) +
                              %w(time_zone language custom_fields other_companies active)
                            ).freeze
  MANDATORY_FIELD_STRING = MANDATORY_FIELD_ARRAY.join(', ').freeze

  attr_accessor :active, :avatar, :view_all_tickets, :custom_fields, :company_name,
                :email, :fb_profile_id, :job_title, :language, :mobile,
                :name, :other_emails, :other_companies, :phone, :tags,
                :time_zone, :twitter_id, :address, :description

  alias_attribute :company_id, :company_name
  alias_attribute :customer_id, :company_name

  # Default fields validation
  validates :language, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field,  message_options: { attribute: 'language', feature: :multi_language } }, unless: :multi_language_enabled?
  validates :time_zone, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field, message_options: { attribute: 'time_zone', feature: :multi_timezone } }, unless: :multi_timezone_enabled?
  validates :email, :phone, :mobile, :company_name, :address, :job_title, :twitter_id, :language, :time_zone, :description, :other_emails, default_field:
                              {
                                required_fields: proc { |x| x.required_default_fields },
                                field_validations: DEFAULT_FIELD_VALIDATIONS
                              }

  validates :name, data_type: { rules: String, required: true }
  validates :name, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :view_all_tickets, data_type: { rules: 'Boolean',  ignore_string: :allow_string_param }
  validates :tags, data_type: { rules: Array, allow_nil: false }, array: { data_type: { rules: String }, custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING } }, string_rejection: { excluded_chars: [','], allow_nil: true }

  validates :active, data_type: { rules: 'Boolean',  ignore_string: :allow_string_param }, custom_inclusion: { in: ['true', true], message: :cannot_deactivate }, if: -> { @active_set }

  validate :contact_detail_missing, if: :email_mandatory?, on: :create

  # Explicitly added since the users created (via web) using fb_profile_id will not have other contact info
  # During the update action, ensure that any one of the contact detail exist including fb_profile_id
  validate :contact_detail_missing_update, if: -> { fb_profile_id.nil? && email_mandatory? }, on: :update

  validates :other_emails, data_type: { rules: Array }, array: { custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } }
  validates :other_emails, custom_length: { maximum: ContactConstants::MAX_OTHER_EMAILS_COUNT, message_options: { element_type: :values } }
  validate :check_contact_for_email_before_adding_other_emails, if: -> { other_emails }
  validate :check_other_emails_for_primary_email, if: -> { other_emails }, on: :update

  validates :company_name, required: {
    allow_nil: false,
    message: :company_id_required
  }, if: -> { view_all_tickets.to_s == 'true' }

  validates :other_companies, custom_absence: {
    message: :require_feature_for_attribute,
    code: :inaccessible_field,
    message_options: {
      attribute: 'other_companies',
      feature: :multiple_user_companies
    }
  }, unless: -> { Account.current.multiple_user_companies_enabled? }

  validate :check_for_default_company_before_adding_other_companies, if: -> {
    other_companies && !other_companies.empty? && company_id.nil? && errors[:company_id].blank?
  }

  validates :other_companies, data_type: { rules: Array }, array: {
    data_type: { rules: Hash },
    allow_nil: true,
    hash: {
      company_id: {
        custom_numericality: {
          ignore_string: :allow_string_param,
          greater_than: 0,
          only_integer: true,
          required: true
        }
      },
      view_all_tickets: {
        data_type: {
          rules: 'Boolean',
          ignore_string: :allow_string_param
        }
      }
    }
  }

  validates :other_companies, custom_length: {
    maximum: ContactConstants::MAX_OTHER_COMPANIES_COUNT,
    message_options: { element_type: :elements }
  }
  validate :check_duplicates_multiple_companies, if: -> {
    other_companies.present? && errors[:other_companies].blank?
  }

  validates :custom_fields, data_type: { rules: Hash }
  validates :custom_fields, custom_field: { custom_fields: {
    validatable_custom_fields: proc { Account.current.contact_form.custom_non_dropdown_fields },
    required_attribute: :required_for_agent,
    ignore_string: :allow_string_param
  }
  }

  validates :avatar, data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true }, file_size: {
    max: ContactConstants::ALLOWED_AVATAR_SIZE }
  validate :validate_avatar, if: -> { avatar && errors[:avatar].blank? }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @current_email = item.email if item
    fill_custom_fields(request_params, item.custom_field) if item && item.custom_field.present?
  end

  def required_default_fields
    Account.current.contact_form.default_contact_fields.select(&:required_for_agent)
  end

  private

    def email_mandatory?
      MANDATORY_FIELD_ARRAY.all? { |x| send(x).blank? && errors[x].blank? }
    end

    def contact_detail_missing
      field = MANDATORY_FIELD_ARRAY.detect { |x| instance_variable_defined?("@#{x}_set") }
      field ? error_options[field] = { code: :invalid_value } : field = :email
      errors[field] = :fill_a_mandatory_field
      (error_options[field] ||= {}).merge!(field_names: MANDATORY_FIELD_STRING)
    end

    alias_method :contact_detail_missing_update, :contact_detail_missing

    def validate_avatar
      valid_extension, extension = ApiUserHelper.avatar_extension_valid?(avatar)
      unless valid_extension
        errors[:avatar] << :upload_jpg_or_png_file
        error_options[:avatar] = { current_extension: extension }
      end
    end

    # Should not allow other_emails if the contact does not have a primary email
    def check_contact_for_email_before_adding_other_emails
      # User triggers a create call with any mandatory field other than email and with other_emails
      # Consider a contact with no emails associated and the user tries to trigger an update call with only other_emails
      if email.nil? && errors[:email].blank?
        errors[:email] << :conditional_not_blank
        self.error_options.merge!(email: { child: 'other_emails' })
      end
    end

    # User triggers an update with current email as an entry in other_emails
    def check_other_emails_for_primary_email
      if email && other_emails.include?(email) && errors[:other_emails].blank?
        errors[:other_emails] << :cant_add_primary_resource_to_others
        self.error_options.merge!(other_emails: {
          resource: "#{email}",
          attribute: 'other_emails',
          status: 'primary email'
        })
      end
    end

    def multi_language_enabled?
      Account.current.features?(:multi_language)
    end

    def multi_timezone_enabled?
      Account.current.features?(:multi_timezone)
    end

    def attributes_to_be_stripped
      ContactConstants::ATTRIBUTES_TO_BE_STRIPPED
    end

    def check_for_default_company_before_adding_other_companies
      errors[:company_id] << :conditional_not_blank
      self.error_options.merge!(company_id: { child: 'other_companies' })
    end

    def check_duplicates_multiple_companies
      ids = other_companies.collect{|x| x[:company_id]}
      if other_companies.any?{|hash| hash[:company_id] == company_id}
        errors[:other_companies] << :cant_add_primary_resource_to_others
        self.error_options.merge!(other_companies: {
          resource: "#{company_id}",
          status: "default company",
          attribute: 'other_companies'
        })
      elsif ids.length != ids.uniq.length
        errors[:other_companies] << :duplicate_companies
      end
    end
end
