module RabbitMq::Subscribers::Companies::Export

  include RabbitMq::Constants

  def mq_export_valid(action, model)
    Account.current.has_any_scheduled_ticket_export?
  end

  def mq_export_subscriber_properties(action)
    {}
  end

  def mq_export_company_properties(action)
    to_rmq_json
  end

end