module RabbitMq::Subscribers::Tickets::Count

  include RabbitMq::Subscribers::Subscriptions::Count
  VALID_MODELS = ["ticket", "ticket_state", "subscription"]

  def mq_count_ticket_valid(action, model)
   ((update_action?(action) && self.respond_to?(:count_fields_updated?)) ? self.count_fields_updated? : true)
  end

  def mq_count_ticket_state_valid(action, model)
    mq_count_ticket_valid(action, model)
  end

  def mq_count_ticket_state_properties(action)
    ticket_properties(self.tickets, action)
  end

  def mq_count_ticket_properties(action)
    ticket_properties(self, action)
  end

  def mq_count_subscriber_properties(action)
    {}
  end

  def count_es_manual_publish(action = "update")
    model_name      = self.class.name.demodulize.tableize.downcase.singularize
    model_uuid      = RabbitMq::Utils.generate_uuid
    model_exchange  = RabbitMq::Constants::MODEL_TO_EXCHANGE_MAPPING[model_name]
    model_message   = RabbitMq::SqsMessage.skeleton_message(model_name, action, model_uuid, Account.current.try(:id) || self.account_id)
    
    model_message["#{model_name}_properties"].deep_merge!(self.safe_send("mq_count_#{model_name}_properties", action))
    model_message["subscriber_properties"].merge!({ 'count' => self.mq_count_subscriber_properties(action) })
    
    RabbitMq::Utils.manual_publish_to_xchg(
      model_uuid, model_exchange, model_message.to_json, RabbitMq::Constants.const_get("RMQ_COUNT_#{model_exchange.upcase}_KEY"), true
    )
  end

  def mq_count_valid(action, model)
    if VALID_MODELS.include?(model) || (model == "ticket" and count_misc_changes?)
      safe_send("mq_count_#{model}_valid", action, model)
    else
      false
    end
  end

  private

    def ticket_properties(model_object, action)
      {
        :document_id  => model_object.id,
        :klass_name   => model_object.class.to_s,
        :action       => action,
        :account_id   => Account.current.try(:id) || model_object.account_id
      }
    end

  def count_misc_changes?
    misc_changes.present? and (misc_changes.has_key?(:add_tag) || misc_changes.has_key?(:remove_tag))
  end

end
