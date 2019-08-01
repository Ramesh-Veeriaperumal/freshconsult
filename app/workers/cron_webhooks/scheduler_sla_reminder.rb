module CronWebhooks
  class SchedulerSlaReminder < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_scheduler_sla_reminder, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    include CronWebhooks::SchedulerHelper

    def perform(args)
      perform_block(args) do
        scheduler_sla_remainder @args[:type]
      end
    end

    private

      def scheduler_sla_remainder(account_type = 'paid')
        Rails.logger.info "SLA Reminder escalation initiated at #{Time.zone.now}"
        enqueue_automation('sla_reminder', account_type)
        Rails.logger.info "SLA Reminder rule check completed at #{Time.zone.now}"
      end
  end
end
