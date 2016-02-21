module RabbitMq::Subscribers::Companies::Search

  def mq_search_valid(action, model)
    Search::V2::SqsSkeleton.es_v2_valid?(self, model) && 
    ((update_action?(action) && self.respond_to?(:esv2_fields_updated?)) ? self.esv2_fields_updated? : true)
  end

  def mq_search_company_properties(action)
    @esv2_company_identifiers ||= Search::V2::SqsSkeleton.model_properties(self, action)
  end

  def mq_search_subscriber_properties(action)
    {}
  end

  def sqs_manual_publish
    Search::V2::SqsSkeleton.manual_publish(self)
  end

  private

    def valid_esv2_model?(model)
      ['company'].include?(model)
    end

end