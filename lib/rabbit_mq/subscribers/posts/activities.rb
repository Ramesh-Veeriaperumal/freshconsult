module RabbitMq::Subscribers::Posts::Activities

  include RabbitMq::Constants

  PROPERTIES_TO_CONSIDER = [:forum_id, :user_id, :topic_id, :published]

  def mq_activities_post_properties(action)
    to_rmq_json(post_keys,action)
  end

  def mq_activities_subscriber_properties(action)
    { :object_id => self.id, :content => valid_changes }
  end

  def mq_activities_valid(action, model)
    false and Account.current.features?(:activity_revamp)
  end

  def valid_changes
    previous_changes.symbolize_keys.select{|k,v| PROPERTIES_TO_CONSIDER.include?(k) }
  end

  private

  def post_keys
    ACTIVITIES_POST_KEYS
  end
end