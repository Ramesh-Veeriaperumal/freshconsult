module CronWebhooks
  class ForumModerationDropTables < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_forum_moderation_drop_tables, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    def perform(args)
      perform_block(args) do
        Rails.logger.info "Running forum_moderation_drop_tables: initiated at #{Time.zone.now}"
        Community::DynamoTables.drop
        Rails.logger.info "Running forum_moderation_drop_tables: completed at #{Time.zone.now}"
      end
    end
  end
end
