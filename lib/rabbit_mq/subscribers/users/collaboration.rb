module RabbitMq::Subscribers::Users::Collaboration  
  include RabbitMq::Constants
  
  def mq_collaboration_subscriber_properties(action)
    {}
  end

  def mq_collaboration_user_properties(action)
    to_rmq_json(collab_keys, action)
  end

  def mq_collaboration_valid(action, model)
    Account.current.collaboration_enabled? &&
      valid_collab_model?(model) && 
      update_action?(action) &&
      valid_collab_agent?
  end

  private  
  def valid_collab_agent?
    self.agent? || (@all_changes.present? && @all_changes.has_key?(:helpdesk_agent))
  end

  def valid_collab_model?(model)
    model == "user"
  end

  def collab_keys
    COLLABORATION_USER_KEYS
  end
end
