module RabbitMq::Subscribers::Articles::Activities

  include RabbitMq::Constants

  PROPERTIES_TO_CONSIDER = [:title, :user_id, :folder_id]

  def mq_activities_article_properties(action)
    to_rmq_json(article_keys, action)
  end

  def mq_activities_subscriber_properties(action)
    {:object_id => self.id,  :content => valid_changes }
  end

  def mq_activities_valid(action, model)
    false and Account.current.features?(:activity_revamp)
  end

  def valid_changes
    previous_changes.symbolize_keys.select{|k,v| PROPERTIES_TO_CONSIDER.include?(k) }
  end

  private

  def article_keys
    ACTIVITIES_ARTICLE_KEYS
  end
end