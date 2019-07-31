module CronWebhooks
  class SchedulerSla < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_scheduler_sla, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    include CronWebhooks::SchedulerHelper

    def perform(args)
      perform_block(args) do
        scheduler_sla @args[:type]
      end
    end

    private

      def scheduler_sla(account_type = 'paid')
        Rails.logger.info "SLA escalation initiated at #{Time.zone.now}"
        enqueue_automation('sla_escalation', account_type)
        Rails.logger.info "SLA rule check completed at #{Time.zone.now}"
      end
  end
end
