module RabbitMq::Init
  def self.start
    begin
      Rails.logger.debug "Connecting to Rabbit MQ..."
      $rabbitmq_config = YAML::load_file(File.join(Rails.root, 'config', 'rabbitmq.yml'))[Rails.env]
      rabbitmq_connection = Bunny.new($rabbitmq_config["connection_config"].symbolize_keys)
      rabbitmq_connection.start
      $rabbitmq_channel = rabbitmq_connection.create_channel
      
      # Ticket Exchange
      rabbitmq_tickets_exchange_1 = $rabbitmq_channel.topic("tickets_1", :durable => true)
      $rabbitmq_ticket_shards = [ rabbitmq_tickets_exchange_1 ] 

    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "RabbitMq Connection Error"}})
      Rails.logger.error("RabbitMq Connection Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
    end
  end
end