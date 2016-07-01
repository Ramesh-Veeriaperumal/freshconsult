module RabbitMq::Subscribers::Accounts::Activities
  
  def mq_activities_account_properties(action)
    { :id => id }
  end

  def mq_activities_subscriber_properties(action)
    {}
  end

  def mq_activities_valid(action, model)
    Account.current.features?(:activity_revamp) && destroy_action?(action)
  end
  
end