module Archive
  class ModifyTicketAssociation < BaseWorker
    sidekiq_options :queue => ::ArchiveSikdekiqConfig["archive_modify_ticket_association"], :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(args)
      begin
        @account = Account.current
        @ticket = @account.tickets.find(args["ticket_id"])
        @archive_ticket = @account.archive_tickets.find_by_id_and_progress(args["archive_ticket_id"],true)
        if @ticket && @archive_ticket
          Archive::Core::Base.new.modify_archive_ticket_association(@ticket,@archive_ticket) 
          split_notes(@ticket,@archive_ticket)
        end
      ensure
        Account.reset_current_account
      end
    end

    def split_notes(ticket,archive_ticket)
      ticket.notes.each do |note|
        archive_note = @account.archive_notes.find_by_note_id(note.id)
        archive_core_base = Archive::Core::Base.new
        if !archive_note
          archive_note = archive_core_base.create_archive_note(note, archive_ticket)
          archive_core_base.create_note_body_association(note,archive_note,archive_ticket)
        else
          archive_core_base.create_note_body_association(note,archive_note,archive_ticket)
        end
        archive_core_base.modify_archive_note_association(note,archive_note)
      end
      Archive::DeleteTicket.perform_async({:account_id => ticket.account_id, :ticket_id => ticket.id})
    end

  end 
end
