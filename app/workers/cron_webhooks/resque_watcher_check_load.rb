module CronWebhooks
  class ResqueWatcherCheckLoad < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_resque_watcher_check_load, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    include CronWebhooks::Constants

    def perform(args)
      perform_block(args) do
        Rails.logger.info "Running resque_watcher_check_load: initiated at #{Time.zone.now}"
        resque_watcher_check_load_job
        Rails.logger.info "Running resque_watcher_check_load: completed at #{Time.zone.now}"
      end
    end

    private

      def get_threshold(queue_name)
        return 10 unless Rails.env.production?

        QUEUE_WATCHER_RULE[:threshold][queue_name] || 15_000
      end

      def resque_watcher_check_load_job
        queues = Resque.queues & (QUEUE_WATCHER_RULE[:only] || Resque.queues) - (QUEUE_WATCHER_RULE[:except] || [])

        queue_info = Hash[*queues.map do |queue_name|
          queue_size = Resque.size(queue_name)
          queue_size > get_threshold(queue_name) ? [queue_name, queue_size] : []
        end.flatten]
        details_hash = {
          subject: 'Resque is queuing up. Needs your attention!',
          additional_info: queue_info
        }

        FreshdeskErrorsMailer.error_email(nil, nil, nil, details_hash) unless queue_info.empty?
        growing_queue_names = queue_info.keys
        if $redis_others.perform_redis_op('get', 'RESQUEUE_JOBS_ALERTED').blank? &&
           !(growing_queue_names & PAGERDUTY_QUEUES).empty?

          Monitoring::PagerDuty.trigger_incident(
            "resque_jobs/#{Time.now}",
            description: 'Resque is queuing up. Needs your attention!',
            details: queue_info
          )
          $redis_others.perform_redis_op('setex', 'RESQUEUE_JOBS_ALERTED', PAGER_DUTY_FREQUENCY_SECS, true)
        end
      end
  end
end
