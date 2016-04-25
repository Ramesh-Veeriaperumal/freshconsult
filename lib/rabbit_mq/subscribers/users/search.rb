module RabbitMq::Subscribers::Users::Search

  include RabbitMq::Subscribers::Search::Sqs
  alias :mq_search_user_properties :mq_search_model_properties

  def mq_search_valid(action, model)
    RabbitMq::Subscribers::Search::SqsUtils.es_v2_valid?(self, model) && 
    ((update_action?(action) && self.respond_to?(:esv2_fields_updated?)) ? self.esv2_fields_updated? : true)
  end

  def mq_search_user_email_properties(action)
    RabbitMq::Subscribers::Search::SqsUtils.model_properties(self.user, 'update')
  end

  private

    def valid_esv2_model?(model)
      ['user', 'user_email'].include?(model)
    end

end