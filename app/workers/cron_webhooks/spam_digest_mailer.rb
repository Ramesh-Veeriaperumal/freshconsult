module CronWebhooks
  class SpamDigestMailer < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_spam_digest_mailer, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    include Redis::RedisKeys
    include Redis::OthersRedis

    def perform(args)
      perform_block(args) do
        enqueue_spam_digest_mailer_jobs
      end
    end

    private

      def enqueue_spam_digest_mailer_jobs
        time_zones = Timezone::Constants::UTC_MORNINGS[Time.zone.now.utc.hour]
        Sharding.execute_on_all_shards do
          Sharding.run_on_slave do
            Account.current_pod.active_accounts.find_in_batches(
              batch_size: 500, conditions: { time_zone: time_zones }
            ) do |accounts|
              accounts.each do |account|
                account.make_current
                forum_spam_digest_recipients = account.forum_moderators.map(&:email).compact
                if account.features_included?(:forums) && forum_spam_digest_recipients.present?
                  Community::DispatchSpamDigest.perform_async
                  Rails.logger.info "** Queued ** #{account} ** for spam digest email **"
                end
                Account.reset_current_account
              end
            end
          end
        end
      end
  end
end
