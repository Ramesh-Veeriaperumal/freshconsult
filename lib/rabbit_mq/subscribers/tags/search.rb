module RabbitMq::Subscribers::Tags::Search

  def mq_search_valid(action, model)
    Search::V2::SqsSkeleton.es_v2_valid?(self, model)
  end

  def mq_search_tag_properties(action)
    @esv2_tag_identifiers ||= Search::V2::SqsSkeleton.model_properties(self, action)
  end

  def mq_search_subscriber_properties(action)
    {}
  end

  def sqs_manual_publish
    Search::V2::SqsSkeleton.manual_publish(self)
  end

  private

    def valid_esv2_model?(model)
      ['tag'].include?(model)
    end

end