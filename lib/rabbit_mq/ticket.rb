module RabbitMq::Ticket
  include RabbitMq::Keys
  include RabbitMq::Properties
  include RabbitMq::Utils
  include RabbitMq::Subscribers::Tickets::AutoRefresh
  include RabbitMq::Subscribers::Tickets::MobileApp
  include RabbitMq::Subscribers::Tickets::ChromeExtension

  def publish_new_ticket_properties_to_rabbitmq
    publish_to_rabbitmq("ticket", "create")
  end

  def publish_updated_ticket_properties_to_rabbitmq
    publish_to_rabbitmq("ticket", "update")
  end
end