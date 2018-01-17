class Bot::TicketValidation < ::TicketValidation
  CHECK_PARAMS_SET_FIELDS = (::TicketValidation::CHECK_PARAMS_SET_FIELDS + %w[bot_external_id query_id conversation_id]).freeze
  attr_accessor :bot_external_id, :query_id, :conversation_id

  validates :bot_external_id, data_type: { rules: String, required: true }
  validates :query_id, data_type: { rules: String, required: true }
  validates :conversation_id, data_type: { rules: String, required: true }
end
