module Archive
  class AccountTicketsChannelWorker < Archive::AccountTicketsWorker
    sidekiq_options queue: :archive_account_tickets_channel_queue, retry: 0, backtrace: true, failures: :exhausted

    private

      def enqueue_ticket_archive_jobs(args = {})
        max_display_id = @account.max_display_id
        @account.tickets.find_in_batches(batch_size: 300, conditions: archive_conditions) do |tickets|
          tickets.each do |ticket|
            next if ticket.association_type.present? || !(ticket.display_id <= max_display_id && !ticket.archive_child)

            Archive::TicketChannelWorker.perform_async(account_id: @account.id, ticket_id: ticket.id, archive_days: @archive_days)
          end
        end
      end
  end
end
