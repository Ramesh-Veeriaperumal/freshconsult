class Tickets::SendAndSetWorker < BaseWorker

  include Helpdesk::Ticketfields::TicketStatus
  
  sidekiq_options :queue => :send_and_set_observer, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform args
    begin
      args.symbolize_keys!
      args[:ticket_changes].symbolize_keys!
      account = Account.current
      evaluate_on = account.tickets.find_by_id args[:ticket_changes][:ticket_id]      
      Tickets::ObserverWorker.new.perform(args[:ticket_changes])
      Tickets::UpdateTicketStatesWorker.new.perform(args[:note_changes])
      status = evaluate_on.status
      if (status == RESOLVED)
        evaluate_on.notify_by_email(EmailNotification::TICKET_RESOLVED) 
        evaluate_on.notify_watchers("resolved")
      end
      if (status == CLOSED)
        evaluate_on.notify_by_email(EmailNotification::TICKET_CLOSED)
        evaluate_on.notify_watchers("closed")
      end
      puts "Send and Set Observer run for Account id:: #{Account.current.id}, Ticket id:: #{args[:ticket_changes][:ticket_id]}, params: #{args} "
    rescue => e
      puts "Something is wrong in Send and Set Observer : Account id:: #{Account.current.id}, Ticket id:: #{args[:ticket_changes][:ticket_id]}, #{e.message}"
      NewRelic::Agent.notice_error(e, {:custom_params => {:args => args }})
      raise e
    end
  end
end
