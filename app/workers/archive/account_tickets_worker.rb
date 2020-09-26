module Archive
  class AccountTicketsWorker < BaseWorker
    include BulkOperationsHelper
    sidekiq_options queue: ::ArchiveSikdekiqConfig['archive_account_tickets'], retry: 0,  failures: :exhausted

    def perform(args)
      @account = Account.current
      return if !@account.active? || @account.disable_archive_enabled?

      args = HashWithIndifferentAccess.new(args)
      execute_on_db do
        @status_id = @account.ticket_statuses.find_by_name(args['ticket_status'].to_s).status_id
        @archive_days = args['archive_days'] || @account.account_additional_settings.archive_days
        @display_ids = args['display_ids']
        enqueue_ticket_archive_jobs(args)
      end
    rescue Exception => e
      Rails.logger.debug "Failure in ArchiveWorker :: #{e.message} :: #{args.inspect}"
    ensure
      Account.reset_current_account
    end

    private

      def archive_conditions
        conditions = ["updated_at < '#{@archive_days.days.ago}' and status = #{@status_id} and deleted = false and spam = false"]
        if @display_ids
          conditions[0] << " and display_id in (?)"
          conditions << @display_ids
        end
        conditions
      end

      def enqueue_ticket_archive_jobs(args)
        max_display_id = @account.max_display_id
        @account.tickets.find_in_batches_with_rate_limit(batch_size: 300, conditions: archive_conditions, rate_limit: rate_limit_options(args)) do |tickets|
          tickets.each do |ticket|
            next if ticket.association_type.present? || !(ticket.display_id <= max_display_id && !ticket.archive_child)

            Archive::TicketWorker.perform_async(account_id: @account.id, ticket_id: ticket.id, archive_days: @archive_days)
          end
        end
      end
  end
end
