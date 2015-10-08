class ContactValidation < ApiValidation
  attr_accessor :avatar, :client_manager, :custom_fields, :company_id, :email, :helpdesk_agent, :job_title, :language,
                :mobile, :name, :phone, :tags, :time_zone, :twitter_id, :address

  validates :avatar, data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true }
  validates :avatar, file_size: {
    min: nil, max: ContactConstants::ALLOWED_AVATAR_SIZE, base_size: 0 }, if: -> { avatar }
  validates :client_manager, data_type: { rules: 'Boolean', allow_nil: true, ignore_string: :allow_string_param }
  validates :company_id,  required: { allow_nil: false, message: 'company_id_required' }, if: -> { client_manager.to_s == 'true' }
  validates :custom_fields, data_type: { rules: Hash }, allow_nil: true
  validates :custom_fields, custom_field: { custom_fields: {
    validatable_custom_fields: proc { Helpers::ContactsValidationHelper.custom_contact_fields },
    required_attribute: :required_for_agent,
    ignore_string: :allow_string_param
  }
  }, if: -> { custom_fields.is_a?(Hash) }
  validates :email, format: { with: ApiConstants::EMAIL_VALIDATOR, message: 'not_a_valid_email' }, data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }, allow_nil: true
  validates :job_title, data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }, allow_nil: true
  validates :language, custom_inclusion: { in: ContactConstants::LANGUAGES }, allow_nil: true
  validates :name, required: true, data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }
  validates :tags,  data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } }
  validates :tags, string_rejection: { excluded_chars: [','] }
  validates :time_zone, custom_inclusion: { in: ContactConstants::TIMEZONES }, allow_nil: true

  validate :contact_detail_missing
  validate :validate_avatar, if: -> { avatar && errors[:avatar].blank? }

  validate :check_update_email, if: -> { email }, on: :update
  validates :phone, :mobile, :address, :twitter_id, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @email_update = true if item && !item.email.nil? && !request_params[:email].nil?
  end

  private

    def contact_detail_missing
      if email.blank? && mobile.blank? && phone.blank? && twitter_id.blank?
        errors.add(:email, 'Please fill at least 1 of email, mobile, phone, twitter_id fields.')
      end
    end

    def validate_avatar
      unless  avatar.original_filename =~ ContactConstants::AVATAR_EXT_REGEX
        errors.add(:avatar, 'Invalid file type. Please upload a jpg or png file')
      end
    end

    def check_update_email
      errors.add(:email, 'Email cannot be updated') if @email_update
    end

    def attributes_to_be_stripped
      ContactConstants::FIELDS_TO_BE_STRIPPED
    end
end
