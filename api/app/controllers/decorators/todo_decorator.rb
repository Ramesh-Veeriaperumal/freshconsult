class TodoDecorator < ApiDecorator
  delegate :id, :body, :deleted, :user_id, :ticket, :created_at, :updated_at, to: :record
  def to_hash
    {
      id: id,
      body: body,
      completed: deleted,
      user_id: user_id,
      ticket_id: ticket.try(:display_id),
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }
  end
end
