module RabbitMq::Subscribers::Tickets::Export

  include RabbitMq::Constants

  VALID_MODELS = ["ticket"]

  def mq_export_valid(action, model)
    export_valid_model?(model) && 
      Account.current.has_any_scheduled_ticket_export? && model_changes? && !import?(action)
  end

  def mq_export_subscriber_properties(action)
    {}
  end

  def mq_export_ticket_properties(action)
    to_rmq_json(EXPORT_TICKET_KEYS, action)
  end

  private

    def export_valid_model?(model)
      VALID_MODELS.include?(model)
    end

    def import? action
      create_action?(action) && self.import_id.present?  
    end

end