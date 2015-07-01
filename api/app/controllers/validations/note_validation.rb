class NoteValidation < ApiValidation
  attr_accessor :body, :body_html, :private, :user_id, :incoming, :notify_emails,
                :ticket_id, :ticket, :attachments, :cc_emails, :bcc_emails, :can_validate_ticket

  validates :user_id, numericality: { allow_nil: true }
  validates :private, :incoming, included: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
  validates :notify_emails, :attachments, :cc_emails, :bcc_emails, data_type: { rules: Array }, allow_nil: true
  validates :notify_emails, :cc_emails, :bcc_emails, array: { format: { with: ApiConstants::EMAIL_REGEX, allow_nil: true, message: 'Should be a valid email address' } }
  validates :attachments, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true, message: 'invalid_format' } }
  validate :valid_ticket_id?, if: -> { can_validate_ticket }

  def initialize(request_params, item, can_validate_ticket = false)
    @can_validate_ticket = can_validate_ticket
    @ticket_id = item.try(:notable_id)
    super(request_params, item)
  end

  def valid_ticket_id?
    @ticket = Account.current.tickets.find_by_param(@ticket_id, Account.current)
    errors.add('ticket_id', "can't be blank") unless @ticket
  end
end
