module RabbitMq::Subscribers::Companies::Search

  include RabbitMq::Subscribers::Search::Sqs
  alias :mq_search_company_properties :mq_search_model_properties

  def mq_search_valid(action, model)
    RabbitMq::Subscribers::Search::SqsUtils.es_v2_valid?(self, model) && 
    ((update_action?(action) && self.respond_to?(:esv2_fields_updated?)) ? self.esv2_fields_updated? : true)
  end

  private

    def valid_esv2_model?(model)
      ['company'].include?(model)
    end

end