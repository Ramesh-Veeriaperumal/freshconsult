module RabbitMq::Subscribers::Forums::Activities

  include RabbitMq::Constants
  VALID_MODELS      = ["forum"]

  def mq_activities_forum_properties(action)
    to_rmq_json(forum_keys, action)
  end

  def mq_activities_subscriber_properties(action)
    {:object_id => self.id, :content => previous_changes.symbolize_keys }
  end

  def mq_activities_valid(action, model)
    false && activity_valid_model?(model)
  end

  private

  def activity_valid_model?(model)
    VALID_MODELS.include?(model)
  end

  def forum_keys
    ACTIVITIES_FORUM_KEYS
  end

end