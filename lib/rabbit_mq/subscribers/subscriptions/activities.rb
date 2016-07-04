module RabbitMq::Subscribers::Subscriptions::Activities

  include RabbitMq::Constants
  include ActivityConstants
  PROPERTIES_TO_CONSIDER = [:user_id]

  def mq_activities_subscription_properties(action)
    to_rmq_json(subscription_keys,action)
  end

  def subscription_subscriber_properties(action)
    { :object_id => self.ticket.display_id , :content => watcher_properties(action) }
  end

  def mq_activities_subscription_valid(action, model)
    Account.current.features?(:activity_revamp) and subscription_valid?
  end

  private

  def subscription_valid?
    User.current and User.current.agent? and !self.ticket.system_changes.present? and !Va::RuleActivityLogger.automation_execution?
  end

  def watcher_properties(action)
    destroy_action?(action) ? {:watcher => {:user_id => [self.user_id, nil]}} : { :watcher => valid_subscription_changes }
  end

  def valid_subscription_changes
    previous_changes.symbolize_keys.select{|k,v| PROPERTIES_TO_CONSIDER.include?(k) }
  end

  def subscription_keys
    ACTIVITIES_SUBSCRIPTION_KEYS
  end
end