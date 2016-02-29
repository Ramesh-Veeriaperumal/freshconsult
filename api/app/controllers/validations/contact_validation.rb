class ContactValidation < ApiValidation
  attr_accessor :avatar, :view_all_tickets, :custom_fields, :company_name, :email, :fb_profile_id, :job_title,
                :language, :mobile, :name, :other_emails, :phone, :tag_names, :time_zone, :twitter_id, :address, :description

  alias_attribute :company_id, :company_name
  alias_attribute :customer_id, :company_name
  alias_attribute :tags, :tag_names

  # Default fields validation
  validates :email, :phone, :mobile, :company_name, :tag_names, :address, :job_title, :twitter_id, :language, :time_zone, :description, :other_emails, default_field:
                              {
                                required_fields: proc { |x| x.required_default_fields },
                                field_validations: ContactConstants::DEFAULT_FIELD_VALIDATIONS
                              }

  validates :name, data_type: { rules: String, required: true }
  validates :name, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :view_all_tickets, data_type: { rules: 'Boolean',  ignore_string: :allow_string_param }

  validate :contact_detail_missing, on: :create

  # Explicitly added since the users created (via web) using fb_profile_id will not have other contact info
  # During the update action, ensure that any one of the contact detail exist including fb_profile_id
  validate :contact_detail_missing_update, if: -> { fb_profile_id.nil? }, on: :update

  validate :check_contact_merge_feature, if: -> { other_emails }
  validates :other_emails, data_type: { rules: Array }, array: { custom_format: { with: ApiConstants::EMAIL_VALIDATOR, message: :not_a_valid_email } }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :other_emails, custom_length: { maximum: ContactConstants::MAX_OTHER_EMAILS_COUNT, message: :max_count_exceeded }
  validate :check_contact_for_email_before_adding_other_emails, if: -> { other_emails }
  validate :check_other_emails_for_primary_email, if: -> { other_emails }, on: :update

  validates :company_name, required: { allow_nil: false, message: :company_id_required }, custom_numericality: { allow_nil: false, ignore_string: :allow_string_param },  if: -> { view_all_tickets.to_s == 'true' }

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
    @tag_names = item.tag_names.split(',') if item && !request_params.key?(:tags)
    @current_email = item.email if item
  end

  def required_default_fields
    Account.current.contact_form.default_contact_fields.select(&:required_for_agent)
  end

  private

    def contact_detail_missing
      if [:email, :mobile, :phone, :twitter_id].all? { |x| send(x).blank? && errors[x].blank? }
        errors[:email] << :fill_a_mandatory_field
      end
    end

    alias_method :contact_detail_missing_update, :contact_detail_missing

    def validate_avatar
      if ContactConstants::AVATAR_EXT.exclude?(File.extname(avatar.original_filename).downcase)
        errors[:avatar] << :upload_jpg_or_png_file
      end
    end

    # Should not allow other_emails if the contact does not have a primary email
    def check_contact_for_email_before_adding_other_emails
      # User triggers a create call with any mandatory field other than email and with other_emails
      # Consider a contact with no emails associated and the user tries to trigger an update call with only other_emails
      if email.nil? && errors[:email].blank?
        errors[:email] << :conditional_not_blank
        (self.error_options ||= {}).merge!(email: { child: 'other_emails' })
      end
    end

    # User triggers an update with current email as an entry in other_emails
    def check_other_emails_for_primary_email
      if email && other_emails.include?(email) && errors[:other_emails].blank?
        errors[:other_emails] << :cant_add_primary_email
        (self.error_options ||= {}).merge!(other_emails: { email: "#{email}" })
      end
    end

    def attributes_to_be_stripped
      ContactConstants::ATTRIBUTES_TO_BE_STRIPPED
    end

    # 'other_emails' is allowed only if the feature Contact Merge UI is enabled for the account
    def check_contact_merge_feature
      unless Account.current.contact_merge_enabled?
        errors[:other_emails] << :require_feature_for_attribute
        (self.error_options ||= {}).merge!(other_emails: { feature: 'Contact Merge', attribute: 'other_emails' })
      end
    end
end
