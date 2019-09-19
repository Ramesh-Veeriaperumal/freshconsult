module RabbitMq::Subscribers::VaRules::Search
  include RabbitMq::Subscribers::Search::Sqs

  VA_RULE_CLASS_NAME = 'VaRule'.freeze

  alias mq_search_va_rule_properties mq_search_model_properties

  def mq_search_valid(_action, model)
    RabbitMq::Subscribers::Search::SqsUtils.es_v2_valid?(self, model)
  end

  private

    def valid_esv2_model?(model)
      ['va_rule'].include?(model) && self.class.name == VA_RULE_CLASS_NAME
    end
end
