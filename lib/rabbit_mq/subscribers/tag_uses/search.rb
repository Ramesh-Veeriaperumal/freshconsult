module RabbitMq::Subscribers::TagUses::Search

  include RabbitMq::Subscribers::Search::Sqs
  alias :mq_search_tag_use_properties :mq_search_model_properties

  def mq_search_valid(action, model)
    RabbitMq::Subscribers::Search::SqsUtils.es_v2_valid?(self, model)
  end

  private

    def valid_esv2_model?(model)
      ['tag_use'].include?(model)
    end

end