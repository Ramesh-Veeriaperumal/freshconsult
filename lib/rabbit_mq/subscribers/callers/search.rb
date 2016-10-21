module RabbitMq::Subscribers::Callers::Search

  include RabbitMq::Subscribers::Search::Sqs
  alias :mq_search_caller_properties :mq_search_model_properties

  def mq_search_valid(action, model)
    RabbitMq::Subscribers::Search::SqsUtils.es_v2_valid?(self, model)
  end

  private

    def valid_esv2_model?(model)
      ['caller'].include?(model)
    end

end