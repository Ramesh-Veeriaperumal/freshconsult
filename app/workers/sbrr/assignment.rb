module SBRR
  class Assignment < BaseWorker

    sidekiq_options :queue => :sbrr_assignment, 
                    :retry => 0, 
                    :backtrace => true, 
                    :failures => :exhausted

    def perform args
      Thread.current[:sbrr_log] = [self.jid]
      Thread.current[:skill_based_round_robin_thread] = true
      @args = args.symbolize_keys
      
      prep_up_ticket
      do_skill_based_round_robin
      save_ticket
    ensure
      Thread.current[:skill_based_round_robin_thread] = nil
      SBRR.logger.debug "#{Thread.current[:sbrr_log]} SBRR Assignment : Ticket => #{@args[:ticket_id]} #{@args.inspect} #{Thread.current[:sbrr_log].join}"
      Thread.current[:sbrr_log] = nil
    end

    def prep_up_ticket
      @ticket = Account.current.tickets.find_by_display_id @args[:ticket_id]
      SBRR.log "Got #{@ticket.inspect}"
      @ticket.model_changes = @args[:model_changes].symbolize_keys
      @ticket.attributes = @args[:attributes]
    end

    def do_skill_based_round_robin
      @ticket.map_skill
      trigger_skill_based_round_robin
      sync_skill_based_queues
    end

    def save_ticket
      @ticket.model_changes = {}
      @ticket.save!
    end

    def trigger_skill_based_round_robin
      #order affects score & behaviour when ticket gets unassigned & current ticket should be assigned first
      user_assigner.assign if @ticket.has_ticket_queue_changes?
      ticket_assigner.assign if @ticket.has_user_queue_changes?
    end

    def sync_skill_based_queues
      user_queue_synchronizer.sync if @ticket.has_user_queue_changes?
      ticket_queue_synchronizer.sync if @ticket.has_ticket_queue_changes?
    end

    def ticket_queue_synchronizer
      SBRR::Synchronizer::TicketUpdate::TicketQueue.new @ticket
    end

    def user_queue_synchronizer
      SBRR::Synchronizer::TicketUpdate::UserQueue.new @ticket
    end

    def ticket_assigner
      SBRR::Assigner::Ticket.new @ticket
    end

    def user_assigner
      SBRR::Assigner::User.new @ticket
    end
  end
end

