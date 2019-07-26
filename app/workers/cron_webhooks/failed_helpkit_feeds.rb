module CronWebhooks
  class FailedHelpkitFeeds < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_failed_helpkit_feeds, retry: 0, dead: true, failures: :exhausted

    include Redis::RedisKeys
    include Redis::OthersRedis
    include CronWebhooks::Constants

    def perform(args)
      perform_block(args) do
        failed_helpkit_feeds_jobs
      end
    end

    private

      def failed_helpkit_feeds_jobs
        return if redis_key_exists?(PROCESSING_FAILED_HELPKIT_FEEDS)

        if set_others_redis_key(PROCESSING_FAILED_HELPKIT_FEEDS, '1')
          FailedHelpkitFeed.find_each do |feed|
            feed.requeue
            feed.destroy
          end
        end
      rescue StandardError => e
        message = "#{e.inspect}\n#{e.backtrace.join("\n")}"
        Rails.logger.info message
        DevNotification.publish(SNS['freshdesk_team_notification_topic'], 'Exception in requeue of failed helpkit feeds', message)
        NewRelic::Agent.notice_error(e)
      ensure
        remove_others_redis_key PROCESSING_FAILED_HELPKIT_FEEDS
      end
  end
end
