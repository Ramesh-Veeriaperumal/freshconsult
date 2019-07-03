class Helpdesk::ResetResponder < BaseWorker

  include Redis::RedisKeys
  include Redis::OthersRedis
  include BulkOperationsHelper

  sidekiq_options :queue => :reset_responder, :retry => 0, :failures => :exhausted
  BATCH_LIMIT = 50

  def perform(args)
    begin
      args.symbolize_keys!
      account     = Account.current
      user_id     = args[:user_id]
      user        = account.all_users.find_by_id(user_id)
      reason      = args[:reason].symbolize_keys!
      options     = { reason: reason, manual_publish: true, rate_limit: rate_limit_options(args) }
      ticket_ids  = []
      ocr_enabled = account.omni_channel_routing_enabled?
      return if user.nil?

      if account.automatic_ticket_assignment_enabled?
        status_ids = Helpdesk::TicketStatus.sla_timer_on_status_ids(account)
        group_ids = account.groups_from_cache.select(&:automatic_ticket_assignment_enabled?).map(&:id)
        account.tickets.visible.sla_on_tickets(status_ids).where(group_id: group_ids).assigned_to(user).select('id').find_in_batches do |tickets|
          ticket_ids.concat(tickets.map(&:id))
        end
      end

      # Reset agent and internal agent for tickets
      account.tickets.where(responder_id: user.id).update_all_with_publish({ responder_id: nil }, {}, options)
      if account.shared_ownership_enabled?
        reason[:delete_internal_agent]  = reason.delete(:delete_agent)
        options                         = {:reason => reason, :manual_publish => true}
        updates_hash                    = {:internal_agent_id => nil}

        tickets = account.tickets.where(:internal_agent_id => user.id)
        tickets.update_all_with_publish(updates_hash, {}, options)
      end

      ticket_ids.each_slice(100).each do |ticket_ids_slice|
        account.tickets.where('id in (?)', ticket_ids_slice).preload(:group).find_each do |ticket|
          if ticket.group.try(:skill_based_round_robin_enabled?)
            trigger_sbrr ticket
          elsif ocr_enabled && ticket.group.omni_channel_routing_enabled? && ticket.eligible_for_ocr?
            ticket.sync_task_changes_to_ocr(nil)
          elsif ticket.group.capping_enabled?
            ticket.assign_tickets_to_agents
          end
        end
      end

      return unless account.features_included?(:archive_tickets)

      account.archive_tickets.where(responder_id: user.id).update_all_with_publish({ responder_id: nil }, {})

    rescue Exception => e
      puts e.inspect, args.inspect
      NewRelic::Agent.notice_error(e, {:args => args})
    end
  end

  def trigger_sbrr ticket
    ticket.sbrr_fresh_ticket = true
    #args = {:model_changes => {}, :ticket_id => ticket.display_id, :attributes => ticket.sbrr_attributes, :sbrr_state_attributes => ticket.sbrr_state_attributes, :options => {:action => "reset_responder", :jid => self.jid}}
    args = {:model_changes => {}, :options => {:action => "reset_responder", :jid => self.jid}}
    SBRR::Execution.enqueue(ticket, args).execute if ticket.eligible_for_round_robin?
  end
end
