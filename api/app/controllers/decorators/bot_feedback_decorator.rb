class BotFeedbackDecorator < ApiDecorator
  delegate :id, :bot_id, :category, :useful, :received_at, :query_id, :query, :state, :chat_id, :customer_id, :client_id, :ticket, to: :record

  def to_hash
    feedback_hash = {
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
      client_id: client_id
    }

    if ticket
      feedback_hash[:ticket_id] = ticket.display_id
      feedback_hash[:requester] = requester_hash
    end
    feedback_hash
  end

  def requester_hash
    ContactDecorator.new(ticket.requester, sideload_options: ['company']).requester_hash
  end
end
