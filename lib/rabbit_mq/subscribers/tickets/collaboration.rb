module RabbitMq::Subscribers::Tickets::Collaboration  
  include RabbitMq::Constants
  
  def mq_collaboration_subscriber_properties(action)
    self.collab_msg.present? ? self.collab_msg : {}
  end

  def mq_collaboration_ticket_properties(action)
    to_rmq_json(collab_keys, action)
  end

  def mq_collaboration_valid(action, model)
    Account.current.collaboration_enabled? && valid_collab_model?(model) && update_action?(action) && ([:status, :responder_id, :subject].any? {|k| @model_changes.key?(k)}.present? || self.collab_msg.present?)
  end

  private
  def valid_collab_model?(model)
    model == "ticket"
  end

  def collab_keys
    COLLABORATION_TICKET_KEYS    
  end
end
