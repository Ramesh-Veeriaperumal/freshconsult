class RabbitmqWorker

  include Sidekiq::Worker
  include RabbitMq::Utils

  sidekiq_options :queue => 'rabbitmq_publish', :retry => 5, :dead => true, :failures => :exhausted

  def perform(exchange_key, message, rounting_key)


    if autorefresh_routing_key?(exchange_key, rounting_key)
        publish_message_to_xchg($rabbitmq_model_exchange[exchange_key], message, rounting_key)
      Rails.logger.info("Published RMQ message via Sidekiq")
    end
    # Publish to Search-v2
    #
    if search_routing_key?(exchange_key, rounting_key)
      # sqs_msg_obj = sqs_v2_push(SQS[:search_etl_queue], message, 0)
      sqs_msg_obj = (Ryuken::SearchSplitter.perform_async(message) rescue nil)
      puts "Searchv2 SQS Message id - #{sqs_msg_obj.try(:message_id)} :: ROUTING KEY -- #{rounting_key} :: Exchange - #{exchange_key}"
    end

    # Publish to Reports-v2
    #
    if reports_routing_key?(exchange_key, rounting_key)
      sqs_msg_obj = sqs_v2_push(SQS[:reports_etl_msg_queue], message, 10)
      puts " SQS Message id - #{sqs_msg_obj.message_id} :: ROUTING KEY -- #{rounting_key} :: Exchange - #{exchange_key}"
    end

    # Publish to ES Count
    if count_routing_key?(exchange_key, rounting_key)
      sqs_msg_obj = (Ryuken::CountPerformer.perform_async(message) rescue nil)
      puts "CountES SQS Message id - #{sqs_msg_obj.try(:message_id)} :: ROUTING KEY -- #{rounting_key} :: Exchange - #{exchange_key}"
    end

    # Publish to Activities-v2
    #
    if activities_routing_key?(exchange_key, rounting_key)
      sqs_msg_obj = sqs_v2_push(SQS[:activity_queue], message, nil)
      puts " SQS Activities Message id - #{sqs_msg_obj.message_id} :: ROUTING KEY -- #{rounting_key} :: Exchange - #{exchange_key}"
    end

    # Handling only the network related failures
  rescue Bunny::ConnectionClosedError, Bunny::NetworkErrorWrapper, NoMethodError => e
    NewRelic::Agent.notice_error(e, {
                                   :custom_params => {
                                     :description => "RabbitMq Sidekiq Publish Error",
                                     :message     => message,
                                     :exchange    => exchange_key,
    }})
    Rails.logger.error("RabbitMq Sidekiq Publish Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
    RabbitMq::Init.restart
    # Re-raising the error to have retry
    raise e
  end

  # Publish to SQS using SDK-v2
  #
  def sqs_v2_push(queue_name, message, delay, opts={})
    AwsWrapper::SqsV2.send_message(queue_name, message, delay, opts)
  rescue => e
    if queue_name == SQS[:activity_queue]
      description = "Activities SQS push error"
      sns_topic = SNS["activities_notification_topic"]
      sns_notification(description, message, sns_topic)
    end
    NewRelic::Agent.notice_error(e, {
                                   :custom_params => {
                                     :description => "SQS push error in #{queue_name}",
                                     :message     => message
    }})
    raise e
  end
  
  def autorefresh_routing_key?(exchange, key)
    if (exchange.starts_with?("tickets") || exchange.starts_with?("notes")) && key[0] == "1"
      return true
    else
      return false
    end
  end

  def activities_routing_key?(exchange, key)
    (
      ((exchange.starts_with?("tickets") && key[8] == "1") || 
          (exchange.starts_with?("notes") && key[6] == "1") ||
          (exchange.starts_with?("archive_tickets") && key[4] == "1") ||
          ((exchange.starts_with?("accounts") || exchange.starts_with?("article") || 
            exchange.starts_with?("topic") || exchange.starts_with?("post")) && key[2] == "1") ||
          ((exchange.starts_with?("forum_category") || exchange.starts_with?("forum") || 
            exchange.starts_with?("time_sheet") || exchange.starts_with?("subscription") || 
            exchange.starts_with?("ticket_old_body")) && key[0] == "1")
      )
    )
  end

  def reports_routing_key?(exchange, key)
    ((exchange.starts_with?("tickets") || exchange.starts_with?("notes")) && key[2] == "1") || 
      ((exchange.starts_with?("archive_tickets") || exchange.starts_with?("accounts")) && key[0] == "1")
  end

  # Key will be like 1.1.1 (Possibility of additional 1s appended in future)
  # Tickets/Notes - Third one is for search
  # ArchiveTickets/Accounts - Second one is for search
  # ArchiveNotes/Articles/Topics/Posts/Tags/Companies/Users - First one is for search
  # Exchange will be like tickets_0, tickets_1
  #
  def search_routing_key?(exchange, key)
    ((exchange.starts_with?("tickets") || exchange.starts_with?("notes")) && key[4] == "1") || 
    ((exchange.starts_with?("archive_tickets") || exchange.starts_with?("accounts")) && key[2] == "1") || 
    ((
      exchange.starts_with?("archive_notes") || exchange.starts_with?("articles") || 
      exchange.starts_with?("topics") || exchange.starts_with?("posts") || exchange.starts_with?("tags") || 
      exchange.starts_with?("companies") || exchange.starts_with?("users") || exchange.starts_with?("tag_uses")
    ) && key[0] == "1")
  end

  def count_routing_key?(exchange, key)
    (exchange.starts_with?("tickets") && key[6] == "1")
  end

end
