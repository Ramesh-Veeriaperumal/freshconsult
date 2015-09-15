# receives account_id and ticket_status as input
# split all the tickets
module Archive
  class TicketsSplitter < BaseWorker
    sidekiq_options :queue => :archive_ticket_splitter, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(args)
      begin
        @account = Account.current
        execute_on_db do
          @status_id = @account.ticket_statuses.find_by_name(args["ticket_status"].to_s).status_id
          @archive_days = @account.account_additional_settings.archive_days
          max_display_id = (@account.max_display_id - 1)

          @account.tickets.find_in_batches(:batch_size => 300, :conditions => archive_conditions) do |tickets|
            tickets.each do |ticket|
              Archive::BuildCreateTicket.perform_async({:account_id => @account.id, :ticket_id => ticket.id }) if ticket.display_id < max_display_id && !ticket.archive_child
            end
          end
        end
      ensure
        Account.reset_current_account
      end
    end

    private

    def archive_conditions
      ["updated_at < ? and status = ? and deleted = ? and spam = ?", @archive_days.days.ago, @status_id, false, false]
    end
  end
end
