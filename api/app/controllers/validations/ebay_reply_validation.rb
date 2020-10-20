class EbayReplyValidation < ApiValidation
  include Ecommerce::Ebay::Constants
  attr_accessor :body, :agent_id

  validates :body, data_type: { rules: String, required: true, allow_nil: false }
  validate :validate_length_of_body, if: -> { body }

  validate :validate_ebay_ticket, if: -> { @ticket.present? }

  def initialize(request_params, item, allow_string_param = false)
    @ticket = item
    super(request_params, nil, allow_string_param)
  end

  def validate_length_of_body
    if body.length > EBAY_REPLY_MSG_LENGTH
      errors[:body] = :ebay_reply_limit_exceeded
      error_options[:body] = { field: :body, code: :ebay_reply_limit_exceeded }
    end
  end

  def validate_ebay_ticket
    errors[:ticket_id] << :not_an_ebay_ticket unless @ticket.source == Helpdesk::Source::ECOMMERCE
  end
end
