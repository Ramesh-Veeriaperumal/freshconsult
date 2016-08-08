class ConversationValidation < ApiValidation
  attr_accessor :body, :private, :user_id, :incoming, :notify_emails,
                :attachments, :cc_emails, :bcc_emails, :item, :from_email

  validates :body, data_type: { rules: String, required: true }
  validates :user_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param, greater_than: 0 }
  validates :private, :incoming, data_type: { rules: 'Boolean', ignore_string: :allow_string_param }
  validates :from_email, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, allow_nil: true, accepted: :'valid email address' } 
  validates :notify_emails, :attachments, :cc_emails, :bcc_emails, data_type: { rules: Array }
  validates :notify_emails, :cc_emails, :bcc_emails, custom_length: { maximum: ApiTicketConstants::MAX_EMAIL_COUNT, message_options: { element_type: :values } }
  validates :notify_emails, :cc_emails, :bcc_emails, array: { custom_format: { with: ApiConstants::EMAIL_VALIDATOR, allow_nil: true, accepted: :'valid email address' } }
  validates :attachments, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true } }

  validates :attachments, file_size: {
    max: ApiConstants::ALLOWED_ATTACHMENT_SIZE,
    base_size: proc { |x| TicketsValidationHelper.attachment_size(x.item) }
  }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
    @body = item.body_html if !request_params.key?(:body) && item
    @item = item
  end

  def attributes_to_be_stripped
    ConversationConstants::ATTRIBUTES_TO_BE_STRIPPED
  end
end
