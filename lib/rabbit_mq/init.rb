module RabbitMq::Init
  def self.start
    begin
      Rails.logger.debug "Connecting to Rabbit MQ..."
      $rabbitmq_config = YAML::load_file(File.join(Rails.root, 'config', 'rabbitmq.yml'))[Rails.env]
      $rabbitmq_shards = $rabbitmq_config["shards"]
      $rabbitmq_shards.times do |shard|
        # Challenging part is to write a logic to re-eshtablish a particular 
        # sharded connection when down 
        $rabbitmq_connection = Bunny.new($rabbitmq_config["connection_config"].symbolize_keys)
        $rabbitmq_connection.start
        $rabbitmq_model_exchange = {}
        # RabbitMQ channel should also be created one per shard
        $rabbitmq_channel = $rabbitmq_connection.create_channel
        $rabbitmq_config["resources"].each do |model|
          $rabbitmq_model_exchange["#{model.pluralize}_#{shard}"] = $rabbitmq_channel.topic(
            "#{model.pluralize}_#{shard}", 
            :durable => true
          )
        end 
      end
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "RabbitMq Connection Error"}})
      Rails.logger.error("RabbitMq Connection Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
    end
  end

  def self.stop
    begin
      Rails.logger.debug "Closing Rabbit MQ connection..."
      $rabbitmq_connection.close
    rescue => e
      NewRelic::Agent.notice_error(e,{
        :custom_params => {
          :description => "RabbitMq Connection Close Error"
        }
      })
      Rails.logger.error("RabbitMq Connection Close Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
    end
  end

  def self.restart
    stop
    start
  end
end