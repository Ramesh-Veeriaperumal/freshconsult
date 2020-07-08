module RabbitMq::Subscribers::Tickets::Search

  include RabbitMq::Subscribers::Search::Sqs
  alias :mq_search_ticket_properties :mq_search_model_properties

  def mq_search_valid(action, model)
    RabbitMq::Subscribers::Search::SqsUtils.es_v2_valid?(self, model) && 
    ((update_action?(action) && self.respond_to?(:esv2_fields_updated?)) ? self.esv2_fields_updated? : true)
  end

  def mq_search_ticket_state_properties(action)
    RabbitMq::Subscribers::Search::SqsUtils.model_properties(self.tickets, 'update')
  end

  def mq_search_subscription_properties(action)
    RabbitMq::Subscribers::Search::SqsUtils.model_properties(self.ticket, 'update')
  end

  def mq_search_ticket_body_properties(action)
    RabbitMq::Subscribers::Search::SqsUtils.model_properties(self.ticket, 'update')
  end

  private

    def valid_esv2_model?(model)
      ['ticket', 'ticket_state', 'subscription', 'ticket_body'].include?(model)
    end

end