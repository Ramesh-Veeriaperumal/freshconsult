class NoteValidation < ApiValidation
  attr_accessor :body, :body_html, :private, :user_id, :incoming, :notify_emails,
                :ticket_id, :ticket, :attachments, :cc_emails, :bcc_emails, :can_validate_ticket, :item

  validates :user_id, :ticket_id, numericality: { allow_nil: true }
  validates :private, :incoming, included: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
  validates :notify_emails, :attachments, :cc_emails, :bcc_emails, data_type: { rules: Array }, allow_nil: true
  validates :notify_emails, :cc_emails, :bcc_emails, array: { format: { with: ApiConstants::EMAIL_REGEX, allow_nil: true, message: 'not_a_valid_email' } }
  validates :attachments, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true, message: 'invalid_format' } }
  validates :ticket, presence: true, if: -> { errors[:ticket_id].blank? && can_validate_ticket }
  validates :attachments, file_size:  {
    min: nil, max: ApiConstants::ALLOWED_ATTACHMENT_SIZE,
    base_size: proc { |x| Helpers::TicketsValidationHelper.attachment_size(x.item) }
  },
                          if: -> { attachments && errors[:attachments].blank? }

  def initialize(request_params, item, can_validate_ticket = false)
    @can_validate_ticket = can_validate_ticket
    @ticket_id = item.try(:notable_id)
    super(request_params, item)
    @item = item
    @ticket = Account.current.tickets.find_by_param(@ticket_id, Account.current) if can_validate_ticket
  end
end
