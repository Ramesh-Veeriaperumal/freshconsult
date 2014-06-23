module RabbitMq::Note
  include RabbitMq::Keys
  include RabbitMq::Utils
  include RabbitMq::Subscribers::Notes::MobileApp

  def publish_new_note_properties_to_rabbitmq
    publish_to_rabbitmq("note", "create")
  end
end