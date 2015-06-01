module RabbitMq::Exchanges::Ticket
  
  def publish_message_to_xchg(message, key)
    Account.current.rabbit_mq_ticket_exchange.
            publish(message.to_json, :routing_key => key, :persistant => true)
  end
  
end
