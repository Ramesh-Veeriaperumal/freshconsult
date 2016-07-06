module RabbitMq::Subscribers::ForumCategories::Activities

  include RabbitMq::Constants

  PROPERTIES_TO_CONSIDER = [:name]

  def mq_activities_forum_category_properties(action)
    to_rmq_json(forum_category_keys,action)
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

  def forum_category_keys
    ACTIVITIES_FORUM_CATEGORY_KEYS
  end
end