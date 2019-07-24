module CronWebhooks
  class PopulateSpamWatcherLimits < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_populate_spam_watcher_limits, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    REDUCE_VALUE = 1000

    def perform(args)
      perform_block(args) do
        Rails.logger.info "Running populate_spam_watcher_limits: initiated at #{Time.zone.now}"
        enqueue_populate_spam_watcher_limits_jobs
        Rails.logger.info "Running populate_spam_watcher_limits: completed at #{Time.zone.now}"
      end
    end

    private

      def enqueue_populate_spam_watcher_limits_jobs
        shards = Sharding.all_shards
        shards.each do |shard_name|
          Rails.logger.info "shard_name is #{shard_name}"
          Sharding.run_on_shard(shard_name.to_sym) do
            max_ticket_id = Helpdesk::Ticket.maximum(:id) - REDUCE_VALUE
            max_note_id = Helpdesk::Note.maximum(:id) - REDUCE_VALUE
            $redis_others.perform_redis_op('set', "#{shard_name}:tickets_limit", max_ticket_id.to_s)
            $redis_others.perform_redis_op('set', "#{shard_name}:notes_limit", max_note_id.to_s)
          end
        end
      end
  end
end
