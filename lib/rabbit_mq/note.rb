module RabbitMq::Note
  include RabbitMq::Keys
  include RabbitMq::Constants
  include RabbitMq::Properties
  include RabbitMq::Utils
  include RabbitMq::Subscribers::Notes::MobileApp
  include RabbitMq::Subscribers::Notes::ChromeExtension

  def publish_new_note_properties_to_rabbitmq
    action = (user and user.agent?) ? ACTION[:agent_reply] : ACTION[:customer_reply]
    publish_to_rabbitmq("note", action)
  end
end