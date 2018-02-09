module RabbitMq::Subscribers::Users::Export

  include RabbitMq::Constants

  def mq_export_valid(action, model)
    model == "user" && Account.current.has_any_scheduled_ticket_export?
  end

  def mq_export_subscriber_properties(action)
    {}
  end

  def mq_export_user_properties(action)
    to_rmq_json(EXPORT_USER_KEYS, action)
  end

end