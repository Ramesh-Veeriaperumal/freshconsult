class BotFeedbackDecorator < ApiDecorator
  delegate :id, :bot_id, :category, :useful, :received_at, :query_id, :query, :state, :chat_id, :customer_id, :client_id, to: :record

  def initialize(record)
    super(record)
  end

  def to_hash
    {
      id: id,
      bot_id: bot_id,
      category: category,
      useful: useful,
      received_at: received_at,
      query_id: query_id,
      query: query,
      state: state,
      chat_id: chat_id,
      customer_id: customer_id,
      client_id: client_id,
    }
  end
end
