module CronWebhooks
  class RequeueCentralPublish < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_requeue_central_publish, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    def perform(args)
      perform_block(args) do
        requeue_central_publisher_jobs
      end
    end

    private

      def requeue_central_publisher_jobs
        if !CentralPublisher.old_task_alive?
          Rails.logger.info "Requeuing failed central feeds at #{Time.zone.now}"
          if CentralPublisher.start_requeue_task
            CentralPublisher::FailedCentralFeed.find_each do |feed|
              feed.requeue
              feed.destroy
            end
          end
        else
          current_task_skipped = true
        end
      rescue StandardError => e
        message = "#{e.inspect}\n#{e.backtrace.join("\n")}"
        CentralPublisher.push_to_newrelic(e, 'Central failed feeds Clear Error', message: message)
      ensure
        CentralPublisher.end_requeue_task unless current_task_skipped
      end
  end
end
