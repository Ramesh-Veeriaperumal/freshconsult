module RabbitMq::Subscribers::Search::Sqs

  def mq_search_model_properties(action)
    RabbitMq::Subscribers::Search::SqsUtils.model_properties(self, action)
  end

  def mq_search_subscriber_properties(action)
    {}
  end

  # Invoked via sqs_manual_publish_without_feature_check due to alias_method_chain
  def sqs_manual_publish
    RabbitMq::Subscribers::Search::SqsUtils.manual_publish(self)
  end

  def sqs_manual_publish_with_feature_check
    return unless Account.current.try(:features?, :es_v2_writes)
    sqs_manual_publish_without_feature_check
  end
  
  alias_method_chain :sqs_manual_publish, :feature_check

end