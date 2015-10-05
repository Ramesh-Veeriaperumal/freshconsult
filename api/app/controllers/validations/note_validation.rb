class NoteValidation < ApiValidation
  attr_accessor :body, :body_html, :private, :user_id, :incoming, :notify_emails,
                :attachments, :cc_emails, :bcc_emails, :item
  validates :user_id, custom_numericality: { allow_nil: true, ignore_string: :string_param }
  validates :private, :incoming, data_type: { rules: 'Boolean', allow_blank: true, ignore_string: :string_param}
  validates :notify_emails, :attachments, :cc_emails, :bcc_emails, data_type: { rules: Array }, allow_nil: true
  validates :notify_emails, :cc_emails, :bcc_emails, array: { format: { with: ApiConstants::EMAIL_VALIDATOR, allow_nil: true, message: 'not_a_valid_email' } }
  validates :attachments, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true, message: 'invalid_format' } }

  validates :attachments, file_size:  {
    min: nil, max: ApiConstants::ALLOWED_ATTACHMENT_SIZE,
    base_size: proc { |x| Helpers::TicketsValidationHelper.attachment_size(x.item) }
  }, if: -> { attachments && errors[:attachments].blank? }

  def initialize(request_params, item, _can_validate_ticket = false)
    super(request_params, item)
    @item = item
  end

  def attributes_to_be_stripped
    NoteConstants::FIELDS_TO_BE_STRIPPED
  end
end
