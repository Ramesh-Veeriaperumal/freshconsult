class RabbitmqWorker

  include Sidekiq::Worker
  include RabbitMq::Utils

  sidekiq_options :queue => 'rabbitmq_publish', :retry => 5, :dead => true, :failures => :exhausted

  class LambdaRequestError < StandardError
  end

  def perform(exchange_key, message, rounting_key, lambda_feature=false)
    Rails.logger.info "RabbitMq :: UUID :: #{JSON.parse(message).fetch('uuid', 'uuid-not-set')}"
    # Publish to cti
    if cti_routing_key?(exchange_key)
      sqs_msg_obj = sqs_v2_push(SQS[:cti_screen_pop], message, 0)
      Rails.logger.info "SQS Message id - #{sqs_msg_obj.message_id} :: ROUTING KEY -- #{rounting_key} :: Exchange - #{exchange_key}"
    end

    # Publish to ES Count
    if count_routing_key?(exchange_key, rounting_key)
      parsed_message = JSON.parse(message)
      publish_to_analytics_cluster(parsed_message, rounting_key, exchange_key)
    end

    # Publish to Search-v2
    #
    if search_routing_key?(exchange_key, rounting_key)
      # sqs_msg_obj = sqs_v2_push(SQS[:search_etl_queue], message, 0)
      hash = JSON.parse(message)
      if hash["subscriber_properties"]["search"] && hash["subscriber_properties"]["search"]["timestamps"]
        stamp = Search::Job.es_version/1000
        hash["subscriber_properties"]["search"]["timestamps"] << stamp
        message = hash.to_json
      end

      unless Rails.env.development?
        sqs_msg_obj = (enqueue_search_sqs(message) rescue nil)
      else
        sqs_msg_obj = (Ryuken::SearchSplitter.new.perform(nil, JSON.parse(message)) rescue nil)
      end
      Rails.logger.info "Searchv2 SQS Message id - #{sqs_msg_obj.try(:message_id)} :: ROUTING KEY -- #{rounting_key} :: Exchange - #{exchange_key}"
    end

    # Publish to Autorefresh, AgentCollision, Collaboration (User and ticket)
    #
    if LAMBDA_ENABLED and lambda_feature
      invoke_lambda(exchange_key, message, rounting_key)
    else
      push_directly_to_sqs(exchange_key, message, rounting_key)
    end

    # Publish to Reports-v2
    #
    if reports_routing_key?(exchange_key, rounting_key)
      sqs_msg_obj = sqs_v2_push(SQS[:reports_etl_msg_queue], message, nil)
      Rails.logger.info "SQS Message id - #{sqs_msg_obj.message_id} :: ROUTING KEY -- #{rounting_key} :: Exchange - #{exchange_key}"
    end

    # Publish to Activities-v2
    #
    if activities_routing_key?(exchange_key, rounting_key)
      sqs_msg_obj = sqs_v2_push(SQS[:activity_queue], message, nil)
      Rails.logger.info "SQS Activities Message id - #{sqs_msg_obj.message_id} :: ROUTING KEY -- #{rounting_key} :: Exchange - #{exchange_key}"
    end

    Rails.logger.info("Published RMQ message via Sidekiq")
  end

  protected

    def invoke_lambda(exchange, message, routing_key)
      options = { function_name: $lambda_interchange[exchange],
                  invocation_type: "Event",
                  payload: message }
      if options[:function_name].present?
        Rails.logger.debug("Lambda :: Account :: #{JSON.parse(message).fetch('account_id', 'not-set')} :: Exchange :: #{exchange}")
        response = $lambda_client.invoke(options)
        raise LambdaRequestError, "Lambda returned #{response[:status_code]}" if response[:status_code] != 202
      end
    rescue => e
      NewRelic::Agent.notice_error(e, {
                                   :custom_params => {
                                     :description => "Lambda Sidekiq Invoke Error",
                                     :message     => message,
                                     :exchange    => exchange,
      }})
      Rails.logger.error("Lambda Sidekiq Publish Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
      push_directly_to_sqs(exchange, message, routing_key)
    end

    def push_directly_to_sqs(exchange_key, message, routing_key)
      if agent_collision_routing_key?(exchange_key, routing_key)
        sqs_msg_obj = sqs_v2_push(SQS[:agent_collision_alb_queue], message, nil)
        print_log("AgentCollision", sqs_msg_obj, routing_key, exchange_key)
        if autorefresh_routing_key?(exchange_key, routing_key)
          sqs_msg_obj = sqs_v2_push(SQS[:auto_refresh_alb_queue], message, nil)
          print_log("Autorefresh", sqs_msg_obj, routing_key, exchange_key)
        end
      end
      if marketplace_app_routing_key?(exchange_key, routing_key)
        sqs_msg_obj = sqs_v2_push(SQS[:marketplace_app_queue], message, nil)
        print_log("Marketplace App", sqs_msg_obj, routing_key, exchange_key)
      end

      publish_for_collab(exchange_key, message, routing_key)
      if iris_routing_key?(exchange_key, routing_key)
        sqs_msg_obj = sqs_v2_push(SQS[:iris_etl_msg_queue], message, nil)
        print_log("Iris ETL", sqs_msg_obj, routing_key, exchange_key)
      end

      if scheduled_ticket_export_key?(exchange_key, routing_key)
        sqs_msg_obj = sqs_v2_push(SQS[:scheduled_export_payload_enricher_queue], message, nil)
        print_log("Scheduled ticket export", sqs_msg_obj, routing_key, exchange_key)
      end
    rescue => e
      NewRelic::Agent.notice_error(e, {
                                   :custom_params => {
                                     :description => "Autorefresh SQS Push Error",
                                     :message     => message
      }})
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

    def sns_publish(topic, message)
      $sns_client.publish(:topic_arn => topic, :message => message)
    rescue => e
      NewRelic::Agent.notice_error(e, {
                                   :custom_params => {
                                     :description => "Autorefresh SNS Publish Error",
                                     :message     => message
      }})
      # Re-raising the error to have retry
      raise e
    end

    def collaboration_ticket_routing_key?(exchange, key)
      (exchange.starts_with?("tickets") && key[12] == "1")
    end

    def collaboration_user_routing_key?(exchange, key)
      (exchange.starts_with?("user") && key[2] == "1")
    end

    def collaboration_account_routing_key?(exchange, key)
      (exchange.starts_with?("account") && key[6] == "1")
    end

    def autorefresh_routing_key?(exchange, key)
      (exchange.starts_with?("tickets") && key[0] == "1")
    end

    def agent_collision_routing_key?(exchange, key)
      ((exchange.starts_with?("tickets") || exchange.starts_with?("notes")) && key[0] == "1")
    end

    def activities_routing_key?(exchange, key)
      (
        ((exchange.starts_with?("tickets") && key[8] == "1") ||
            (exchange.starts_with?("notes") && key[6] == "1") ||
            ((exchange.starts_with?("accounts") || exchange.starts_with?("article") ||
              exchange.starts_with?("topic") || exchange.starts_with?("post")) && key[2] == "1") ||
            ((exchange.starts_with?("forum_category") || exchange.starts_with?("forum") ||
              exchange.starts_with?("time_sheet") || exchange.starts_with?("subscription") ||
              exchange.starts_with?("ticket_body")) && key[0] == "1")
        )
      )
    end

    def reports_routing_key?(exchange, key)
      ((exchange.starts_with?("tickets") || exchange.starts_with?("notes")) && key[2] == "1") ||
        ((exchange.starts_with?("archive_tickets") || exchange.starts_with?("accounts")) && key[0] == "1") ||
          (exchange.starts_with?("tag_uses") && key[2] == "1") || (exchange.starts_with?("tags") && key[2] == "1")
    end

    def iris_routing_key?(exchange, key)
      (exchange.starts_with?("tickets") && key[14] == "1") ||
      	(exchange.starts_with?("notes") && key[8] == "1") ||
        (exchange.starts_with?("archive_tickets") && key[4] == "1") ||
        (exchange.starts_with?("accounts") && key[4] == "1") ||
        (exchange.starts_with?("users") && key[4] == "1")
    end

    def cti_routing_key?(exchange)
      exchange.include?("cti_calls")
    end

    def scheduled_ticket_export_key?(exchange, key)
      (exchange.starts_with?("tickets") && key[16] == "1") ||
      (exchange.starts_with?("users") && key[6] == "1") ||
      (exchange.starts_with?("companies") && key[2] == "1")
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
        exchange.starts_with?("companies") || exchange.starts_with?("users") || exchange.starts_with?("tag_uses") ||
        exchange.starts_with?('callers') || exchange.starts_with?('va_rules')
      ) && key[0] == "1")
    end

    def count_routing_key?(exchange, key)
      (exchange.starts_with?("tickets") && key[6] == "1")
    end

    def marketplace_app_routing_key?(exchange, key)
      (exchange.starts_with?("tickets") && key[10] == "1")
    end

    def print_log(log, sqs_msg_obj, routing_key, exchange_key)
      Rails.logger.info "#{log} SQS Message id - #{sqs_msg_obj.message_id} :: ROUTING KEY -- #{routing_key} :: Exchange - #{exchange_key}"
    end

    def publish_for_collab(exchange_key, message, routing_key)
      if collaboration_ticket_routing_key?(exchange_key, routing_key)
        sqs_msg_obj = sqs_v2_push(SQS[:collab_ticket_update_queue], message, nil)
        Rails.logger.info "Collaboration SQS Message id - #{sqs_msg_obj.message_id} :: ROUTING KEY -- #{routing_key} :: Exchange - #{exchange_key}"
      end
      if collaboration_user_routing_key?(exchange_key, routing_key)
        sqs_msg_obj = sqs_v2_push(SQS[:collab_agent_update_queue], message, nil)
        Rails.logger.info "Collaboration SQS Message id - #{sqs_msg_obj.message_id} :: ROUTING KEY -- #{routing_key} :: Exchange - #{exchange_key}"
      end
      if collaboration_account_routing_key?(exchange_key, routing_key)
        sqs_msg_obj = sqs_v2_push(SQS[:collab_ticket_update_queue], message, nil)
        Rails.logger.info "Collaboration SQS Message id - #{sqs_msg_obj.message_id} :: ROUTING KEY -- #{routing_key} :: Exchange - #{exchange_key}"
      end
    end

    def publish_to_analytics_cluster(message, rounting_key, exchange_key)
      sqs_msg_obj = enqueue_analytics_sqs(message.to_json)
      Rails.logger.info "CountES Analytics SQS Message id - #{sqs_msg_obj.try(:message_id)} :: ROUTING KEY -- #{rounting_key} :: Exchange - #{exchange_key}"
    rescue Exception => e
      Rails.logger.debug "Error while publishing to analytics cluster :: #{e.message}"
    end

    def enqueue_search_sqs(message)
      Ryuken::SearchSplitter.perform_async(message)
    end

    def enqueue_analytics_sqs(message)
      Ryuken::AnalyticsCountPerformer.perform_async(message)
    end

end
