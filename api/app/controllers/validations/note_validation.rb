class NoteValidation < ApiValidation
  attr_accessor :body, :body_html, :private, :user_id, :incoming, :notify_emails,
                :ticket_id, :ticket, :attachments, :cc_emails, :bcc_emails, :can_validate_ticket, :item

  validates :user_id, numericality: { allow_nil: true }
  validates :ticket_id, required: { allow_nil: false, message: 'required_and_numericality' }, if: -> { can_validate_ticket }
  validates :ticket_id, numericality: true, allow_nil: true, if: -> { can_validate_ticket }
  validates :private, :incoming, custom_inclusion: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
  validates :notify_emails, :attachments, :cc_emails, :bcc_emails, data_type: { rules: Array }, allow_nil: true
  validates :notify_emails, :cc_emails, :bcc_emails, array: { format: { with: ApiConstants::EMAIL_REGEX, allow_nil: true, message: 'not_a_valid_email' } }
  validates :attachments, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: true, message: 'invalid_format' } }

  # Can't check for presence as ticket.blank? introduces 4 queries because of respond_to? override. Hence custom validation
  validate :valid_ticket?, if: -> { errors[:ticket_id].blank? && can_validate_ticket }
  validates :attachments, file_size:  {
    min: nil, max: ApiConstants::ALLOWED_ATTACHMENT_SIZE,
    base_size: proc { |x| Helpers::TicketsValidationHelper.attachment_size(x.item) }
  }, if: -> { attachments && errors[:attachments].blank? }

  def initialize(request_params, item, can_validate_ticket = false)
    @can_validate_ticket = can_validate_ticket
    @ticket_id = item.try(:notable_id)
    super(request_params, item)
    @item = item
    @ticket = Account.current.tickets.find_by_param(@ticket_id, Account.current) if can_validate_ticket
  end

  def valid_ticket?
    errors.add(:ticket_id, :blank) unless @ticket
  end

  def attributes_to_be_stripped
    NoteConstants::FIELDS_TO_BE_STRIPPED
  end
end
