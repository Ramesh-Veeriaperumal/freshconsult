class NoteValidation < ApiValidation
  attr_accessor :body, :body_html, :private, :user_id, :incoming, :notify_emails,
                :attachments, :cc_emails, :bcc_emails, :item

  validates :body, required: true
  validates :user_id, custom_numericality: { allow_nil: true, ignore_string: :allow_string_param }
  validates :private, :incoming, data_type: { rules: 'Boolean', ignore_string: :allow_string_param }
  validates :notify_emails, :attachments, :cc_emails, :bcc_emails, data_type: { rules: Array }
  validates :notify_emails, :cc_emails, :bcc_emails, array: { format: { with: ApiConstants::EMAIL_VALIDATOR, allow_nil: true, message: 'not_a_valid_email' } }
  validates :attachments, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true } }

  validates :attachments, file_size:  {
    min: nil, max: ApiConstants::ALLOWED_ATTACHMENT_SIZE,
    base_size: proc { |x| Helpers::TicketsValidationHelper.attachment_size(x.item) }
  }, if: -> { attachments }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @item = item
    @body = request_params[:body_html] if should_set_body?(request_params)
  end

  def should_set_body?(request_params)
    request_params[:body].nil? && request_params[:body_html].present?
  end

  def attributes_to_be_stripped
    NoteConstants::ATTRIBUTES_TO_BE_STRIPPED
  end
end
