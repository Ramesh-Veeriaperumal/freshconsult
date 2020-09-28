module CronWebhooks
  class ArchiveAutomation < CronWebhooks::CronWebhookWorker
    include Redis::ArchiveRedis
    sidekiq_options queue: :cron_archive_automation, retry: 0, dead: true, failures: :exhausted

    def perform(args = {})
      perform_block(args) do
        archive_automation_jobs
      end
    end

    private

      def archive_automation_jobs
        return run_for_account if @args[:account_id]

        run_for_shards
      end

      def run_for_account
        Sharding.select_shard_of(@args[:account_id]) do
          perform_archive(@args[:account_id])
        end
      end

      def run_for_shards
        runnable_shards.each do |shard_name|
          Sharding.run_on_shard(shard_name) do
            current_archive_shard = ActiveRecord::Base.current_shard_selection.shard.to_s + '_archive'
            account_ids_in_shard(current_archive_shard).each do |account_id|
              perform_archive(account_id)
            end
          end
        end
      end

      def runnable_shards
        if @args[:shard_name]
          all_shards = Sharding.all_shards
          all_shards & @args[:shard_name].to_a # validate shard names provided as arguement
        else
          archive_automation_shards
        end
      end

      def perform_archive(account_id)
        account = Account.find(account_id).make_current
        return if account.disable_archive_enabled?

        Archive::AccountTicketsWorker.perform_async(account_id: account_id, ticket_status: :closed)
      rescue StandardError => e
        Rails.logger.debug "Error in Archive automation :: #{e.message}"
      end
  end
end
