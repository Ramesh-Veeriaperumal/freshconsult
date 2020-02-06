module Search
  module Analytics
    class TicketsCleanupWorker < ::BaseWorker
      sidekiq_options queue: :search_analytics_tickets_cleanup, retry: 1, failures: :exhausted

      def perform(args)
        args = HashWithIndifferentAccess.new(args)
        start_display_id = args[:start_display_id]
        end_display_id = args[:end_display_id]
        es_ids = []
        db_ids = []
        Sharding.select_shard_of(args[:account_id]) do
          Sharding.run_on_slave do
            account = Account.find(args[:account_id]).make_current
            es_ids = get_ids_from_es(start_display_id, end_display_id)
            db_ids = get_ids_from_db(es_ids)
          end
        end
        deleted_ids = es_ids - db_ids
        Rails.logger.info "Deleted ids: #{deleted_ids.inspect}" if deleted_ids.present?
        deleted_ids.each do |id|
          payload = {}
          payload[:klass_name] = 'Helpdesk::Ticket'
          payload[:document_id] = id
          Search::Dashboard::Count.new(payload).remove_es_count_document
        end
      rescue StandardError => e
        Rails.logger.error "Failure in Search::Analytics::TicketsCleanupWorker :: #{e.message} :: #{args.inspect}"
        NewRelic::Agent.notice_error(e, description: 'Failure in Search::Analytics::TicketsCleanupWorker')
      ensure
        Account.reset_current_account
      end

      private

        def get_ids_from_es(start_display_id, end_display_id)
          query = "display_id:>#{start_display_id} AND display_id:<#{end_display_id}"
          response = Freshquery::Runner.instance.construct_es_query('ticketanalytics', query.to_json)
          terms = response.terms.to_json
          template_name = 'searchTicketApi'
          es_params = { search_terms: terms, account_id: Account.current.id, offset: 0, size: 100 }
          request_id = UUIDTools::UUID.timestamp_create.hexdigest
          searchable_types = ['ticketanalytics']
          payload = SearchService::Utils.construct_payload(searchable_types, template_name, es_params)
          res = SearchService::Client.new(Account.current.id).query(payload, request_id, search_type: template_name)
          res.records['results'].map { |re| re['id'] }
        end

        def get_ids_from_db(es_ids)
          return es_ids if es_ids.blank?
          Account.current.tickets.where(id: es_ids).pluck(:id)
        end
    end
  end
end
