module RabbitMq::Subscribers::Topics::Activities

  include RabbitMq::Constants

  PROPERTIES_TO_CONSIDER = [:forum_id, :user_id, :title, :stamp_type]

  def mq_activities_topic_properties(action)
    to_rmq_json(topic_keys,action)
  end

  def mq_activities_subscriber_properties(action)
    { :object_id => self.id, :content => valid_changes }
  end

  def mq_activities_valid(action, model)
    false and Account.current.features?(:activity_revamp)
  end

  def valid_changes
    if previous_changes.has_key?("merged_topic_id")
      {:activity_type => {:type => "topic_merge", :source_topic_id => self.id, :target_topic_id => previous_changes["merged_topic_id"][1]}}
    else
      previous_changes.symbolize_keys.select{|k,v| PROPERTIES_TO_CONSIDER.include?(k) }
    end
  end

  private

  def topic_keys
    ACTIVITIES_TOPIC_KEYS
  end
end