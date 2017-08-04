module RabbitMq::Subscribers::Accounts::Collaboration
  
  def mq_collaboration_account_properties(action)
    { :id => id }
  end

  def mq_collaboration_subscriber_properties(action)
    {}
  end

  def mq_collaboration_valid(action, model)
    valid_collab_model?(model) and destroy_action?(action)
  end
  private
  
  def valid_collab_model?(model)
    ["account"].include?(model)
  end

end