module RabbitMq::Subscribers::Tickets::Search

  def mq_search_valid(action, model)
    Search::V2::SqsSkeleton.es_v2_valid?(self, model) && 
    ((update_action?(action) && self.respond_to?(:esv2_fields_updated?)) ? self.esv2_fields_updated? : true)
  end

  def mq_search_ticket_properties(action)
    @esv2_ticket_identifiers ||= Search::V2::SqsSkeleton.model_properties(self, action)
  end

  def mq_search_ticket_state_properties(action)
    @esv2_ticket_state_identifiers ||= Search::V2::SqsSkeleton.model_properties(self.tickets, 'update')
  end

  def mq_search_subscription_properties(action)
    @esv2_subscription_identifiers ||= Search::V2::SqsSkeleton.model_properties(self.ticket, 'update')
  end

  def mq_search_ticket_old_body_properties(action)
    @esv2_ticket_old_body_identifiers ||= Search::V2::SqsSkeleton.model_properties(self.ticket, 'update')
  end

  def mq_search_subscriber_properties(action)
    {}
  end

  def sqs_manual_publish
    Search::V2::SqsSkeleton.manual_publish(self)
  end

  private

    def valid_esv2_model?(model)
      ['ticket', 'ticket_state', 'subscription', 'ticket_old_body'].include?(model)
    end

end