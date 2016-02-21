module RabbitMq::Subscribers::Articles::Search

  def mq_search_valid(action, model)
    Search::V2::SqsSkeleton.es_v2_valid?(self, model)
  end

  def mq_search_article_properties(action)
    @esv2_article_identifiers ||= Search::V2::SqsSkeleton.model_properties(self, action)
  end

  def mq_search_subscriber_properties(action)
    {}
  end

  def sqs_manual_publish
    Search::V2::SqsSkeleton.manual_publish(self)
  end

  private

    def valid_esv2_model?(model)
      ['article'].include?(model)
    end

end