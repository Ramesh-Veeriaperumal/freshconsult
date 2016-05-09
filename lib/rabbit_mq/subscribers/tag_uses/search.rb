module RabbitMq::Subscribers::TagUses::Search

  include RabbitMq::Subscribers::Search::Sqs

  def mq_search_valid(action, model)
    RabbitMq::Subscribers::Search::SqsUtils.es_v2_valid?(self, model)
  end

  def mq_search_tag_use_properties(action)
    RabbitMq::Subscribers::Search::SqsUtils.model_properties(self.taggable, 'update')
  end

  private

    def valid_esv2_model?(model)
      ['tag_use'].include?(model)
    end

end