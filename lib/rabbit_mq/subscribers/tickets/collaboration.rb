module RabbitMq::Subscribers::Tickets::Collaboration  
  include RabbitMq::Constants
  
  def mq_collaboration_subscriber_properties(action)
    @model_changes.present? && @model_changes[:responder_id].present? ? responder_noti_data : {}
  end

  def mq_collaboration_ticket_properties(action)
    to_rmq_json(collab_keys, action)
  end

  def mq_collaboration_valid(action, model)
    Account.current.collaboration_enabled? && valid_collab_model?(model) && update_action?(action) && [:status, :responder_id, :subject].any? {|k| @model_changes.key?(k)}.present?
  end

  private
  def valid_collab_model?(model)
    model == "ticket"
  end

  def collab_keys
    COLLABORATION_TICKET_KEYS    
  end

  def responder_noti_data
    collab_msg = {}
    new_assignee_present = @model_changes[:responder_id][1].present?
    if new_assignee_present
      from_info = parse_email(self.selected_reply_email) || parse_email(Account.current.default_friendly_email)
      collab_msg = {
        :from_email_address => from_info[:email],
        :from_name => from_info[:name],
        :client_id => Collaboration::Ticket::HK_CLIENT_ID,
        :to_email_address => self.responder.email,
        :user_id => self.responder_id.to_s,
        :user_name => self.responder_name,
        :requester_name => self.requester[:name],
        :requester_email => self.requester[:email],
        :current_domain => Account.current.full_domain
      }
    end
    collab_msg
  end
end
