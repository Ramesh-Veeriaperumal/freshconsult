module CronWebhooks
  class SqsMonitor < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_sqs_monitor, retry: 0, dead: true, failures: :exhausted

    SQS_THRESHOLD = {
      facebook_realtime_queue: 50
    }.freeze

    def perform(args)
      perform_block(args) do
        queue_name = @args[:queue_name]
        monitor_queue(queue_name)
      end
    end

    private

      def monitor_queue(queue_name)
        raise 'Queue name missing' unless queue_name

        queue_name_mapping = SQS[queue_name.to_sym]
        sqs = AWS::SQS.new.queues.named(queue_name_mapping)
        msgs_in_queue = sqs.approximate_number_of_messages if sqs
        params = {
          queue_name: queue_name_mapping,
          msgs_in_queue: msgs_in_queue
        }
        if msgs_in_queue > SQS_THRESHOLD[queue_name.to_sym]
          NewRelic::Agent.notice_error('SQS Threshold reached', custom_params: params)
          SocialErrorsMailer.deliver_threshold_reached(params)
          Rails.logger.debug "SQS threshold reached #{params.inspect}"
        else
          Rails.logger.debug "SQS threshold have not reached #{params.inspect}"
        end
      end
  end
end
