module CronWebhooks
  class ForumModerationCreateTables < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_forum_moderation_create_tables, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    def perform(args)
      perform_block(args) do
        Rails.logger.info "Running forum_moderation_create_tables: initiated at #{Time.zone.now}"
        Community::DynamoTables.create
        Rails.logger.info "Running forum_moderation_create_tables: completed at #{Time.zone.now}"
      end
    end
  end
end
