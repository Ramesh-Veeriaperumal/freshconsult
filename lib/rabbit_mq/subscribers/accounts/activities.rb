module RabbitMq::Subscribers::Accounts::Activities
  
  def mq_activities_account_properties(action)
    { :id => id }
  end

  def mq_activities_subscriber_properties(action)
    {}
  end

  def mq_activities_valid(action, model)
    activity_valid_model?(model) and destroy_action?(action)
  end
  private
  
  def activity_valid_model?(model)
    ["account"].include?(model)
  end

end