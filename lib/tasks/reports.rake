namespace :reports do 
  
  desc "Poll Rabbitmq for the model updates related to reports "
  task :poll_rmq => :environment do

    # TODO Need to get the exchange via api
    reports_queue = $rabbitmq_channel.queue("reports_1")
    
    # @REV need to change the routing key
    $rabbitmq_ticket_shards.each do |ticket_exchange|
     reports_queue.bind(ticket_exchange, :routing_key => "*.1.#" )
    end
    
    reports_queue.subscribe(:block => true) do |delivery_info, properties, body|
      puts body.inspect
    end
  end
  
end