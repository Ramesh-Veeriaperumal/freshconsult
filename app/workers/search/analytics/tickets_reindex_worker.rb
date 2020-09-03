module Search
  module Analytics
    class TicketsReindexWorker < ::BaseWorker
      sidekiq_options queue: :search_analytics_tickets_reindex, retry: 1, failures: :exhausted

      def perform(args)
        return if args.blank?

        account = Account.current
        execute_on_db('run_on_master') do
          args.each do |ticket|
            search_payload = {
              'document_id' => ticket[0],
              'klass_name' => 'Helpdesk::Ticket',
              'action' => 'update',
              'account_id' => account.id,
              'version' => ticket[1]
            }
            Search::Dashboard::Count.new(search_payload).index_es_count_document
          end
        end
      rescue StandardError => e
        Rails.logger.error "Failure in Search::Analytics::TicketsReindexWorker :: #{e.message} :: #{args.inspect}"
        NewRelic::Agent.notice_error(e, description: "Failure in Search::Analytics::TicketsReindexWorker #{account.id}")
      ensure
        Account.reset_current_account
      end
    end
  end
end
