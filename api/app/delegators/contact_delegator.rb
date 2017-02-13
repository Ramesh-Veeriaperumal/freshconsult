class ContactDelegator < BaseDelegator
  include ActiveRecord::Validations

  validates :custom_field, custom_field: { custom_field: {
    validatable_custom_fields: proc { Account.current.contact_form.custom_drop_down_fields },
    drop_down_choices: proc { Account.current.contact_form.custom_dropdown_field_choices },
    required_attribute: :required_for_agent
  }
  }
  validate :user_emails_validation, if: -> { @other_emails }
  validate :validate_user_activation, on: :send_invite
  validate :validate_avatar_ext, if: -> { self.avatar && errors[:attachment_ids].blank? }
  validate :default_company_presence, if: -> { @default_company }

  def initialize(record, options = {})
    if options[:email_objects]
      @other_emails = options[:email_objects][:old_email_objects]
      @primary_email = options[:email_objects][:primary_email]
    else
      @other_emails = options[:other_emails]
      @primary_email = options[:primary_email]
    end
    @default_company = options[:default_company]
    @user_id = record.id
    check_params_set(options[:custom_fields]) if options[:custom_fields].is_a?(Hash)
    options[:attachment_ids] = Array.wrap(options[:avatar_id].to_i) if options[:avatar_id]
    super(record, options)
    self.avatar = @draft_attachments.first if @draft_attachments
  end

  # Web displays a generic error message "Email has already been taken" when we try to add emails associated to other users
  # It is displayed when the call to update_attributes fails
  # In API V2 the validation handled prior to the update_attributes call, also the error message will contain the list of erroneous emails
  def user_emails_validation
    # Find out the emails that are not associated to the current user
    invalid_other_emails = unassociated_emails - [@primary_email]
    if invalid_other_emails.any?
      errors[:other_emails] << :email_already_taken
      (self.error_options ||= {}).merge!(other_emails: { invalid_emails: "#{invalid_other_emails.join(', ')}" })
    end
    errors[:email] << :"Email has already been taken" if unassociated_emails.include?(@primary_email)
  end

  def unassociated_emails
    @emails ||= @other_emails.select { |x| id != x.user_id }.map(&:email)
  end

  def validate_user_activation
    errors[:id] << :unable_to_perform if deleted || blocked || active
  end

  def validate_avatar_ext
    valid_extension, extension = ApiUserHelper.avatar_extension_valid?(self.avatar)
    unless valid_extension
      errors[:avatar_id] << :upload_jpg_or_png_file
      error_options[:avatar_id] = { current_extension: extension }
    end
  end

  def default_company_presence
    unless Account.current.companies_from_cache.detect { |x| x.id == @default_company}
      errors[:company_id] << :"can't be blank"
    end
  end

  private

    def attachment_size
      ContactConstants::ALLOWED_AVATAR_SIZE
    end
end
