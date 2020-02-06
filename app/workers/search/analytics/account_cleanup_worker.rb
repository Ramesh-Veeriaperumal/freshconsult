module Search
  module Analytics
    class AccountCleanupWorker < ::BaseWorker
      BATCH_SIZE = 10_000
      INDIVIDUAL_BATCH_SIZE = 100
      RUN_AFTER = 120

      sidekiq_options queue: :search_analytics_account_cleanup, retry: 1, failures: :exhausted

      def perform(args)
        args = HashWithIndifferentAccess.new(args)
        first_display_id = args[:first_display_id] || 1
        last_display_id = args[:last_display_id] || find_last_display_id(args)
        current_batch_count = args[:count] || 0

        current_batch_start_display_id = first_display_id + (current_batch_count * BATCH_SIZE)
        ((BATCH_SIZE / INDIVIDUAL_BATCH_SIZE) + 1).times do |n|
          start_display_id = current_batch_start_display_id + (n * INDIVIDUAL_BATCH_SIZE)
          end_display_id = start_display_id + INDIVIDUAL_BATCH_SIZE
          break if start_display_id > last_display_id

          Rails.logger.info "Enqueuing Search::Analytics::TicketsCleanupWorker with account_id: #{args[:account_id]}, start_display_id: #{start_display_id}, end_display_id: #{end_display_id}"
          Search::Analytics::TicketsCleanupWorker.perform_async(account_id: args[:account_id], start_display_id: start_display_id, end_display_id: end_display_id)
        end

        if (current_batch_start_display_id + BATCH_SIZE) < last_display_id
          current_batch_count += 1
          job_args = {}
          job_args[:account_id] = args[:account_id]
          job_args[:count] = current_batch_count
          job_args[:first_display_id] = first_display_id
          job_args[:last_display_id] = last_display_id
          Rails.logger.info "Enqueuing Search::Analytics::AccountCleanupWorker with: #{job_args.inspect}"
          Search::Analytics::AccountCleanupWorker.perform_in(RUN_AFTER, job_args)
        else
          Rails.logger.info "Finished Search::Analytics::AccountCleanupWorker with: #{job_args.inspect}"
          log_cleanup_in_additional_settings(args)
        end
      rescue StandardError => e
        Rails.logger.error "Failure in Search::Analytics::AccountCleanupWorker :: #{e.message} :: #{args.inspect}"
        NewRelic::Agent.notice_error(e, description: 'Failure in Search::Analytics::AccountCleanupWorker')
      end

      private

        def log_cleanup_in_additional_settings(args)
          Sharding.select_shard_of(args[:account_id]) do
            account = Account.find(args[:account_id]).make_current
            account.account_additional_settings.additional_settings[:last_count_es_cleanedup_time] = Time.now.utc
            account.account_additional_settings.save
          end
        end

        def find_last_display_id(args)
          Sharding.select_shard_of(args[:account_id]) do
            account = Account.find(args[:account_id]).make_current
            account.max_display_id
          end
        end
    end
  end
end
