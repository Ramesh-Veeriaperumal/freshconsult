module Archive
  class DeleteTicket < BaseWorker
    sidekiq_options :queue => :archive_delete_ticket, :retry => 0, :backtrace => true, :failures => :exhausted
    def perform(args)
      begin
        @account = Account.current
        @ticket = @account.tickets.find(args["ticket_id"])
        @archive_ticket = @account.archive_tickets.find_by_ticket_id_and_progress(args["ticket_id"],true)
        Archive::Core::Base.new.delete_ticket(@ticket,@archive_ticket) if @ticket && @archive_ticket       
      ensure
        Account.reset_current_account
      end
    end
  end
end
