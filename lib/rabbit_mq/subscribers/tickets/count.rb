module RabbitMq::Subscribers::Tickets::Count

  def mq_count_valid(action, model)
    Account.current.features?(:countv2_writes) && valid_count_model?(model) &&
   ((update_action?(action) && self.respond_to?(:count_fields_updated?)) ? self.count_fields_updated? : true)
  end

  def mq_count_ticket_state_properties(action)
    properties(self.tickets, action)
  end

  def mq_count_ticket_properties(action)
   properties(self, action)
  end

  def mq_count_subscriber_properties(action)
    {}
  end

  def count_es_manual_publish
    action          = 'update' #=> Always keeping manual publish as update
    model_name      = self.class.name.demodulize.tableize.downcase.singularize
    model_uuid      = RabbitMq::Utils.generate_uuid
    model_exchange  = RabbitMq::Constants::MODEL_TO_EXCHANGE_MAPPING[model_name]
    model_message   = RabbitMq::SqsMessage.skeleton_message(model_name, action, model_uuid, Account.current.try(:id) || self.account_id)
    
    model_message["#{model_name}_properties"].deep_merge!(self.send("mq_count_#{model_name}_properties", action))
    model_message["subscriber_properties"].merge!({ 'count' => self.mq_count_subscriber_properties(action) })
    
    RabbitMq::Utils.manual_publish_to_xchg(
      model_uuid, model_exchange, model_message.to_json, RabbitMq::Constants.const_get("RMQ_COUNT_#{model_exchange.upcase}_KEY")
    )
  end

  private

    def valid_count_model?(model)
      ['ticket', 'ticket_state'].include?(model)
    end

    def properties(model_object, action)
      {
        :document_id  => model_object.id,
        :klass_name   => model_object.class.to_s,
        :action       => action,
        :account_id   => Account.current.try(:id) || model_object.account_id
      }
    end

end