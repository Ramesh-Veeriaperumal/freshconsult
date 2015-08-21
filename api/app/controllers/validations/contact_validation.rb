class ContactValidation < ApiValidation
  attr_accessor :avatar, :client_manager, :custom_fields, :company_id, :email, :helpdesk_agent, :job_title, :language,
                :mobile, :name, :phone, :tags, :time_zone, :twitter_id

  validates :avatar, data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true }
  validates :avatar, file_size: {
    min: nil, max: ContactConstants::ALLOWED_AVATAR_SIZE, base_size: 0 }, if: -> { avatar && errors[:avatar].blank? }
  validates :client_manager, custom_inclusion: { in: ApiConstants::BOOLEAN_VALUES }, allow_nil: true
  validates :company_id,  required: { allow_nil: false, message: 'company_id_required' }, if: -> { client_manager.to_s == 'true' }
  validates :custom_fields, data_type: { rules: Hash }, allow_nil: true
  validates :custom_fields, custom_field: { custom_fields: {
      validatable_custom_fields: proc { Helpers::ContactsValidationHelper.custom_contact_fields },
      required_attribute: :required_for_agent
    }
  }, if: -> { custom_fields.is_a?(Hash) }
  validates :email, format: { with: AccountConstants::EMAIL_VALIDATOR, message: 'not_a_valid_email' }, data_type: { rules: String }, allow_nil: true
  validates :job_title, data_type: { rules: String }, allow_nil: true
  validates :language, data_type: { rules: String }, custom_inclusion: { in: ContactConstants::LANGUAGES }, allow_nil: true
  validates :name, data_type: { rules: String }, required: true
  validates :tags,  data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: String } }
  validates :time_zone, custom_inclusion: { in: ContactConstants::TIMEZONES }, allow_nil: true

  validate :contact_detail_missing
  validate :validate_avatar, if: -> { avatar && errors[:avatar].blank? }

  validate :check_update_email, if: -> { email }, on: :update

  def initialize(request_params, item)
    super(request_params, item)
    @email_update = true if item && !item.email.nil? && !request_params[:email].nil?
  end

  private

    def contact_detail_missing
      if email.blank? && mobile.blank? && phone.blank? && twitter_id.blank?
        errors.add(:email, 'Please fill at least 1 of email, mobile, phone, twitter_id fields.')
      end
    end

    def validate_avatar
      # errors.add(:avatar, 'File size should be < 5 MB') if avatar.size > ContactConstants::ALLOWED_AVATAR_SIZE
      unless  avatar.original_filename =~ ContactConstants::AVATAR_EXT_REGEX
        errors.add(:avatar, 'Invalid file type. Please upload a jpg or png file')
      end
    end

    def check_update_email
      errors.add(:email, 'Email cannot be updated') if @email_update
    end
end
