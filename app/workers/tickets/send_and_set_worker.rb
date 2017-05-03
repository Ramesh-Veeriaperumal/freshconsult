class Tickets::SendAndSetWorker < BaseWorker

  include Helpdesk::Ticketfields::TicketStatus
  
  sidekiq_options :queue => :send_and_set_observer, :retry => 0, :backtrace => true, :failures => :exhausted

  class SendSetObserverError < StandardError
  end

  def perform args
    args.symbolize_keys!
    @account = Account.current
    fire_ticket_observer(args)
    fire_note_observer(args)
    fire_notifications
    puts "Send and Set Observer run for Account id:: #{Account.current.id}, params: #{args} "
    raise SendSetObserverError if @errors.present?
  end

  def fire_ticket_observer(args) 
    if args[:ticket_changes]
      args[:ticket_changes].symbolize_keys!
      @evaluate_on = @account.tickets.find_by_id(args[:ticket_changes][:ticket_id])
      Tickets::ObserverWorker.new.perform(args[:ticket_changes])
    end
  rescue => e
    @errors = true
    puts "Something is wrong in Send and Set Observer:fire_ticket_observer : Account id:: #{Account.current.id}, #{e.message}"
    NewRelic::Agent.notice_error(e, {:custom_params => {:args => args }})    
  end

  def fire_note_observer(args)
    Tickets::UpdateTicketStatesWorker.new.perform(args[:note_changes])
  rescue => e
    @errors = true
    puts "Something is wrong in Send and Set Observer:fire_note_observer : Account id:: #{Account.current.id}, #{e.message}"
    NewRelic::Agent.notice_error(e, {:custom_params => {:args => args }})
  end

  def fire_notifications
    return unless @evaluate_on.present?
    if (@evaluate_on.status == RESOLVED)
      @evaluate_on.notify_by_email(EmailNotification::TICKET_RESOLVED) 
      @evaluate_on.notify_watchers("resolved")
    end
    if (@evaluate_on.status == CLOSED)
      @evaluate_on.notify_by_email(EmailNotification::TICKET_CLOSED)
      @evaluate_on.notify_watchers("closed")
    end
  rescue => e
    @errors = true
    puts "Something is wrong in Send and Set Observer:fire_notifications : Account id:: #{Account.current.id}, #{e.message}"
    NewRelic::Agent.notice_error(e)
  end
end