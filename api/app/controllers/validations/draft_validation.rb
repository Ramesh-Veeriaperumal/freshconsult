class DraftValidation < ApiValidation
  attr_accessor :cc_emails, :bcc_emails, :body, :from_email

  validates :body, data_type: { rules: String, required: true, allow_nil: false }, on: :save_draft
  validates :cc_emails, :bcc_emails, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: false }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } }
  validates :cc_emails, :bcc_emails, custom_length: { maximum: ApiTicketConstants::MAX_EMAIL_COUNT, message_options: { element_type: :values } }
  validates :from_email, data_type: { rules: String, allow_nil: true }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end
end
