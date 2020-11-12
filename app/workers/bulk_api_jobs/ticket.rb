# frozen_string_literal: true

module BulkApiJobs
  class Ticket < BulkApiJobs::Worker
    sidekiq_options queue: :bulk_api_jobs, retry: 0, failures: :exhausted

    private

      def process_bulk_delete_payload(payload, _succeeded)
        args = { 'action' => :delete, 'bulk_background' => true }
        args['ids'] = payload['ids']
        bulk_ticket_action = ::Tickets::BulkTicketActions.new
        bulk_ticket_action.perform(args)
        [bulk_ticket_action.status_list, bulk_ticket_action.success_count]
      end
  end
end
