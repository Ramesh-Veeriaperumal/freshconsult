class Tickets::SendAndSetWorker < BaseWorker

  include Helpdesk::Ticketfields::TicketStatus
  
  sidekiq_options :queue => :send_and_set_observer, :retry => 0, :failures => :exhausted
  SEND_AND_SET_OBSERVER_ERROR = 'SEND_AND_SET_OBSERVER_EXECUTION_FAILED'.freeze
  SEND_AND_SET_OBSERVER_TICKET_ERROR = (SEND_AND_SET_OBSERVER_ERROR + '::TICKET').freeze
  SEND_AND_SET_OBSERVER_NOTE_ERROR = (SEND_AND_SET_OBSERVER_ERROR + '::NOTE').freeze
  SEND_AND_SET_OBSERVER_NOTIFICATION_ERROR = (SEND_AND_SET_OBSERVER_ERROR + '::NOTIFICATION').freeze

  class SendSetObserverError < StandardError
  end

  def perform args
    args.symbolize_keys!
    args[:ticket_changes].try(:symbolize_keys!)
    @account = Account.current
    Va::Logger::Automation.set_thread_variables(@account.id, args[:ticket_changes].try(:[], :ticket_id), args[:ticket_changes].try(:[], :doer_id))
    Va::Logger::Automation.log("Send and Set Worker", true)
    fire_ticket_observer(args)
    fire_note_observer(args)
    fire_notifications
    raise SendSetObserverError if @errors.present?
  ensure
    Va::Logger::Automation.unset_thread_variables
  end

  def fire_ticket_observer(args) 
    if args[:ticket_changes]
      args[:ticket_changes].symbolize_keys!
      @evaluate_on = @account.tickets.find_by_id(args[:ticket_changes][:ticket_id])
      return Tickets::ServiceTaskObserverWorker.new.perform(args[:ticket_changes]) if @evaluate_on.service_task?

      Tickets::ObserverWorker.new.perform(args[:ticket_changes])
    end
  rescue => e
    @errors = true
    Va::Logger::Automation.log_error(SEND_AND_SET_OBSERVER_TICKET_ERROR, e, args)
    NewRelic::Agent.notice_error(e, {:custom_params => {:args => args }})    
  end

  def fire_note_observer(args)
    Tickets::UpdateTicketStatesWorker.new.perform(args[:note_changes])
  rescue => e
    @errors = true
    Va::Logger::Automation.log_error(SEND_AND_SET_OBSERVER_NOTE_ERROR, e, args)
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
    Va::Logger::Automation.log_error(SEND_AND_SET_OBSERVER_NOTIFICATION_ERROR, e, args)
    NewRelic::Agent.notice_error(e)
  end
end