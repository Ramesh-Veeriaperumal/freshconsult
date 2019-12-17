class DraftValidation < ApiValidation
  attr_accessor :cc_emails, :bcc_emails, :body, :quoted_text, :from_email, :articles_suggested

  validates :body, data_type: { rules: String, required: true, allow_nil: false }, on: :save_draft
  validates :quoted_text, data_type: { rules: String, allow_nil: true }, on: :save_draft
  validates :cc_emails, :bcc_emails, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: false }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } }
  validates :cc_emails, :bcc_emails, custom_length: { maximum: ApiTicketConstants::MAX_EMAIL_COUNT, message_options: { element_type: :values } }
  validates :from_email, data_type: { rules: String, allow_nil: true }
  validates :articles_suggested,
            data_type: { rules: Array },
            array: {
              data_type: { rules: Hash },
              hash: {
                validatable_fields_hash: proc { |x| x.articles_suggested_fields_validation }
              }
            }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end

  def articles_suggested_fields_validation
    {
      language: { data_type: { rules: String }, custom_inclusion: { in: Language.all_codes, required: true } },
      article_id: { data_type: { rules: Integer, allow_nil: false }, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param, required: true } }
    }
  end
end
