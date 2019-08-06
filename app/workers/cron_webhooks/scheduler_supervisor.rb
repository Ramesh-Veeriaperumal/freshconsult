module CronWebhooks
  class SchedulerSupervisor < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_scheduler_supervisor, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    include CronWebhooks::SchedulerHelper

    def perform(args)
      perform_block(args) do
        scheduler_supervisor @args[:type]
      end
    end

    private

      def scheduler_supervisor(account_type = 'paid')
        Rails.logger.info "Running #{account_type} supervisor initiated at #{Time.zone.now}"
        enqueue_automation('supervisor', account_type)
        Rails.logger.info "Running #{account_type} supervisor completed at #{Time.zone.now}"
      end
  end
end
