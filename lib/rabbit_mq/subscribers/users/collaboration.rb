module RabbitMq::Subscribers::Users::Collaboration  
  include RabbitMq::Constants
  
  def mq_collaboration_subscriber_properties(action)
    {}
  end

  def mq_collaboration_user_properties(action)
    to_rmq_json(collab_keys, action)
  end

  def mq_collaboration_valid(action, model)
    Account.current.collab_feature_enabled? &&
      valid_collab_model?(model) && 
      valid_collab_agent? &&
      update_action?(action)
  end

  private  
  def valid_collab_agent?
    self.agent? || @all_changes.has_key?(:helpdesk_agent)
  end

  def valid_collab_model?(model)
    model == "user"
  end

  def collab_keys
    COLLABORATION_USER_KEYS
  end
end
