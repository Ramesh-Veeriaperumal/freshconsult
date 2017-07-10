module SBRR
  class Execution

    attr_reader :ticket

    def self.enqueue _ticket, _args = {}
      args = { 
        :model_changes => _ticket.sbrr_model_changes, 
        :ticket_id => _ticket.display_id, 
        :skip_skill_remap => _ticket.ticket_update_skill_alone?, 
        :attributes => _ticket.sbrr_attributes, 
        :sbrr_state_attributes => _ticket.sbrr_state_attributes
      }
      args.merge!(_args)
      SBRR::Execution.new args
    end

  	def initialize args
      @args = args.deep_symbolize_keys
      SBRR.log @args.inspect
      Thread.current[:sbrr_log] ||= [@args[:options][:jid]] if @args[:options][:jid]
      Thread.current[:skill_based_round_robin_thread] = true
      Thread.current[:mass_assignment] = @args[:options][:action]
  	end

    def execute
      prep_up_ticket
      do_skill_based_round_robin
      save_ticket if !skip_save? && has_changes?
    rescue Exception => e
      SBRR.log @args.inspect
    ensure
      Thread.current[:skill_based_round_robin_thread] = nil
      Thread.current[:mass_assignment] = nil
      SBRR.logger.debug "#{Thread.current[:sbrr_log]} SBRR Assignment : Ticket => #{@args[:ticket_id]} #{@args.inspect} #{Thread.current[:sbrr_log]}"
      Thread.current[:sbrr_log] = nil unless skip_set_sbrr_log_nil?
    end

    def prep_up_ticket
      @ticket = Account.current.tickets.find_by_display_id @args[:ticket_id]
      SBRR.log "Args: #{@args.inspect}"
      @ticket.model_changes = @args[:model_changes].symbolize_keys
      @ticket.attributes = @args[:attributes]
      @ticket.sbrr_state_attributes = @args[:sbrr_state_attributes]
    end

    def do_skill_based_round_robin
      #Order affects when ticket gets unassigned and unassigned agent's score will not be synced if SBRR is triggered before syncing queues
      @ticket.map_skill unless @args[:skip_skill_remap]
      SBRR.log "Model changes after remap skill #{@ticket.model_changes.inspect}"
      sync_skill_based_queues
      trigger_skill_based_round_robin unless skip_assigner?
    end

    def save_ticket
      @ticket.model_changes = {}
      @ticket.save!
    end

    def trigger_skill_based_round_robin
      ticket_pull
      ticket_push
    end

    def ticket_pull
      @assigner_ticket = ticket_assigner.assign if @ticket.has_user_queue_changes?
    end

    def ticket_push
      user_assigner.assign if @ticket.has_ticket_queue_changes? && !skip_user_assigner?(@assigner_ticket)
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

    def skip_save?
      @ticket.skip_sbrr_save
    end

    def skip_assigner?
      @ticket.skip_sbrr_assigner
    end

    def skip_user_assigner? assigner_ticket
      #skipping user assigner when ticket assigner has picked up the current ticket
      assigner_ticket && assigner_ticket[:assigned].try(:id) == @ticket.id
    end

    def skip_set_sbrr_log_nil?
      ["status_sla_toggled_to_on", "status_sla_toggled_to_off", "update_multiple_sync", "sbrr_turned_on_for_group"].include? @args[:options][:action]
    end

    def has_changes?
      @ticket.changes.present?
    end

  end
end
