module RabbitMq::Subscribers::Search::Sqs

  def mq_search_model_properties(action)
    RabbitMq::Subscribers::Search::SqsUtils.model_properties(self, action)
  end

  def mq_search_subscriber_properties(action)
    {}
  end

  def sqs_manual_publish
    return unless (Account.current and Account.current.features?(:es_v2_writes))
    RabbitMq::Subscribers::Search::SqsUtils.manual_publish(self)
  end

end