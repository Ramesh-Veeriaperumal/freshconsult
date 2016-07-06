module RabbitMq::Subscribers::Accounts::Activities
  
  def mq_activities_account_properties(action)
    { :id => id }
  end

  def mq_activities_subscriber_properties(action)
    {}
  end

  def mq_activities_valid(action, model)
    # valid_model?(model) && destroy_action?(action)
    # needs to be changed.
    false
  end
  private
  
  def valid_model?(model)
    ["account"].include?(model)
  end

end