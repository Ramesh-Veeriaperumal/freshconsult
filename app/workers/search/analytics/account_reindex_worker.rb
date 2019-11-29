module Search
  module Analytics
    class AccountReindexWorker < ::BaseWorker
      SYNC_AGO = 900
      include BulkOperationsHelper
      sidekiq_options queue: :search_analytics_account_reindex, retry: 1, failures: :exhausted

      def perform(args)
        account = Account.current
        return unless account.active?

        args = HashWithIndifferentAccess.new(args)
        execute_on_db('run_on_master') do
          relation = account.tickets
          relation = relation.where('updated_at >= ?', args[:from]) if args[:from].present?
          relation = relation.where('updated_at <= ?', args[:to]) if args[:to].present?
          individual_batch_size_limit = individual_batch_size
          relation.select('id, updated_at').find_in_batches_with_rate_limit(batch_size: individual_batch_size_limit, rate_limit: rate_limit_options(args)) do |tickets|
            enqueue_job(tickets) if tickets.present?
            log_time_in_additional_settings(account) if tickets.size < individual_batch_size_limit
          end
        end
      rescue StandardError => e
        Rails.logger.error "Failure in Search::Analytics::AccountReindexWorker :: #{e.message} :: #{args.inspect}"
        NewRelic::Agent.notice_error(e, description: "Failure in Search::Analytics::AccountReindexWorker #{account.id}")
      ensure
        Account.reset_current_account
      end

      def enqueue_job(tickets)
        ticket_ids = []
        tickets.each do |ticket|
          ticket_ids << [ticket.id, ([ticket.updated_at, SYNC_AGO.seconds.ago].max.to_f * 1_000_000).ceil]
        end
        Search::Analytics::TicketsReindexWorker.perform_async(ticket_ids)
      end

      def log_time_in_additional_settings(account)
        account.account_additional_settings.additional_settings[:last_tickets_reindexed_count_analytics_time] = Time.now.utc
        account.account_additional_settings.save
      end
    end
  end
end
