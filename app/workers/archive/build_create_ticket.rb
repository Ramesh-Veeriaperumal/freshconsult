module Archive
  class BuildCreateTicket < BaseWorker
    sidekiq_options :queue => :archive_build_create_ticket, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(args)
      begin
        @account = Account.current
        @ticket = @account.tickets.find(args["ticket_id"])
        @ticket.reset_associations
        archive_ticket = @account.archive_tickets.find_by_ticket_id_and_progress(args["ticket_id"],true)
        archvie_core_base = Archive::Core::Base.new
        if !archive_ticket
          archive_ticket = archvie_core_base.create_archive_ticket(@ticket)
          archvie_core_base.create_archive_ticket_body(archive_ticket,@ticket)
        else
          archvie_core_base.create_archive_ticket_body(archive_ticket,@ticket)
        end
        Archive::ModifyTicketAssociation.perform_async({
                    :account_id => @account.id, 
                    :ticket_id => @ticket.id, 
                    :archive_ticket_id => archive_ticket.id
                    }) if archive_ticket && archive_ticket.progress 
      ensure
        Account.reset_current_account
      end
    end
  end
end
