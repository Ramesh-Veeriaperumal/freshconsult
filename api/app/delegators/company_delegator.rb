class CompanyDelegator < BaseDelegator
  include ActiveRecord::Validations

  validates :custom_field, custom_field: { custom_field: {
    validatable_custom_fields: proc { Account.current.company_form.custom_drop_down_fields },
    drop_down_choices: proc { Account.current.company_form.custom_dropdown_field_choices },
    required_attribute: :required_for_agent
  } }

  validate :validate_avatar_ext, if: -> { @avatar_attachment && errors[:attachment_ids].blank? }

  def initialize(record, options = {})
    check_params_set(options[:custom_fields]) if options[:custom_fields].is_a?(Hash)
    options[:attachment_ids] = Array.wrap(options[:avatar_id].to_i) if options[:avatar_id]
    super(record, options)
    @avatar_attachment = @draft_attachments.first if @draft_attachments
  end

  def validate_avatar_ext
    valid_extension, extension = ApiUserHelper.avatar_extension_valid?(@avatar_attachment)
    unless valid_extension
      errors[:avatar_id] << :upload_jpg_or_png_file
      error_options[:avatar_id] = { current_extension: extension }
    end
  end

  private

    def attachment_size
      ContactConstants::ALLOWED_AVATAR_SIZE
    end
end
