class Notifications::Email::BccValidation < ApiValidation
  include BccConcern
  attr_accessor :emails

  validates :emails, data_type: { rules: Array, required: true, allow_nil: true }, array: { data_type: { rules: String } }
  validate :bcc_emails_length, if: -> { errors[:emails].blank? }

  def bcc_emails_length
    bcc_email_string = build_bcc_params(emails)
    if bcc_email_string.length > ApiConstants::MAX_LENGTH_STRING
      errors[:emails] = :too_long
      error_options.merge!(emails: { current_count: bcc_email_string.length, element_type: 'characters', max_count: ApiConstants::MAX_LENGTH_STRING })
    end
  end
end
