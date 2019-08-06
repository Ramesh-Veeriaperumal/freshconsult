module CronWebhooks
  class ReportsBuildNoActivity < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_reports_build_no_activity, retry: 0, dead: true, failures: :exhausted

    def perform(args)
      perform_block(args) do
        Reports::BuildNoActivity.new.execute_task
      end
    end
  end
end
