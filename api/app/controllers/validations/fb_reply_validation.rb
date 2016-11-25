class FbReplyValidation < ApiValidation
  attr_accessor :body, :note_id, :agent_id

  validates :body, data_type: { rules: String, required: true, allow_nil: false }
  validates :note_id, :agent_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }

  validate :validate_facebook_ticket, if: -> { @ticket.present? }

  def initialize(request_params, item, allow_string_param = false)
    @ticket = item
    super(request_params, nil, allow_string_param)
  end

  def validate_facebook_ticket
    errors[:ticket_id] << :not_a_facebook_ticket unless @ticket.source == TicketConstants::SOURCE_KEYS_BY_TOKEN[:facebook]
  end
end
