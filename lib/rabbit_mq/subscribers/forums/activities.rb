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
    false and Account.current.features?(:activity_revamp) and valid_model?(model)
  end

  private

  def valid_model?(model)
    VALID_MODELS.include?(model)
  end

  def forum_keys
    ACTIVITIES_FORUM_KEYS
  end

end