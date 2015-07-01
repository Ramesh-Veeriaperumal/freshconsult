class NoteValidation < ApiValidation
  attr_accessor :body, :body_html, :private, :user_id, :incoming, :notify_emails, :ticket_id, :attachments, :cc_emails, :bcc_emails

  validates :user_id, numericality: { allow_nil: true }
  validates :ticket_id, numericality: true
  validates :private, :incoming, included: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
  validates :notify_emails, :attachments, :cc_emails, :bcc_emails, data_type: { rules: Array }, allow_nil: true
  validates :notify_emails, :cc_emails, :bcc_emails, array: { format: { with: ApiConstants::EMAIL_REGEX, allow_nil: true, message: 'Should be a valid email address' } }
  validates :attachments, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true, message: 'invalid_format' } }

  def initialize(request_params, item)
    @ticket_id = item.try(:notable_id)
    super(request_params, item)
  end
end
