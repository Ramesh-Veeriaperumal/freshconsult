class ContactValidation < ApiValidation
  attr_accessor :avatar, :client_manager, :custom_fields, :company_name, :email, :helpdesk_agent, :job_title, :language,
                :mobile, :name, :phone, :tag_names, :time_zone, :twitter_id, :address, :description

  alias_attribute :company_id, :company_name
  alias_attribute :customer_id, :company_name
  alias_attribute :tags, :tag_names

  # Default fields validation
  validates :email, :phone, :mobile, :company_name, :tag_names, :address, :job_title, :twitter_id, :language, :time_zone, :description, default_field:
                              {
                                required_fields: proc { |x| x.required_default_fields },
                                field_validations: ContactConstants::DEFAULT_FIELD_VALIDATIONS
                              }

  validates :name, required: true, data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }
  validates :client_manager, data_type: { rules: 'Boolean', allow_nil: true,  ignore_string: :allow_string_param }

  validate :contact_detail_missing
  validate :check_update_email, if: -> { email }, on: :update

  validates :company_name, required: { allow_nil: false, message: :company_id_required }, if: -> { client_manager.to_s == 'true' }

  validates :custom_fields, data_type: { rules: Hash }
  validates :custom_fields, custom_field: { custom_fields: {
    validatable_custom_fields: proc { Account.current.contact_form.custom_non_dropdown_fields },
    required_attribute: :required_for_agent,
    ignore_string: :allow_string_param
  }
  }

  validates :avatar, data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true }, file_size: {
    min: nil, max: ContactConstants::ALLOWED_AVATAR_SIZE, base_size: 0 }, if: -> { avatar }
  validate :validate_avatar, if: -> { avatar && errors[:avatar].blank? }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @email_update = true if item && !item.email.nil? && !request_params[:email].nil?
    @tag_names = item.tag_names.split(',') if item && !request_params.key?(:tags)
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

    def validate_avatar
      if ContactConstants::AVATAR_EXT.exclude?(File.extname(avatar.original_filename).downcase)
        errors[:avatar] << :upload_jpg_or_png_file
      end
    end

    def check_update_email
      errors[:email] << :email_cant_be_updated if @email_update
    end

    def attributes_to_be_stripped
      ContactConstants::ATTRIBUTES_TO_BE_STRIPPED
    end
end
