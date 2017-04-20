class Helpdesk::ResetResponder < BaseWorker

  include Redis::RedisKeys
  include Redis::OthersRedis

  sidekiq_options :queue => :reset_responder, :retry => 0, :backtrace => true, :failures => :exhausted
  BATCH_LIMIT = 50

  def perform(args)
    begin
      args.symbolize_keys!
      account     = Account.current
      user_id     = args[:user_id]
      user        = account.all_users.find_by_id(user_id)
      reason      = args[:reason].symbolize_keys!
      options     = {:reason => reason, :manual_publish => true}
      ticket_ids  = []
      return if user.nil?

      account.tickets.preload(:group).assigned_to(user).find_each do |ticket|
        ticket_ids.push(ticket.id) if ticket.group.present? && (ticket.group.capping_enabled? || ticket.group.skill_based_round_robin_enabled?)
      end if account.features?(:round_robin) || account.skill_based_round_robin_enabled?

      # Reset agent and internal agent for tickets
      account.tickets.where(responder_id: user.id).update_all_with_publish({ responder_id: nil }, {}, options)
      if account.shared_ownership_enabled?
        reason[:delete_internal_agent]  = reason.delete(:delete_agent)
        options                         = {:reason => reason, :manual_publish => true}
        updates_hash                    = {:internal_agent_id => nil}

        tickets = account.tickets.where(:internal_agent_id => user.id)
        tickets.update_all_with_publish(updates_hash, {}, options)
      end

      account.tickets.where("id in (?)", ticket_ids).preload(:group).find_each do |ticket|
        if ticket.group.try(:skill_based_round_robin_enabled?)
          trigger_sbrr ticket
        else
          ticket.assign_tickets_to_agents
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
    args = {:model_changes => {}, :ticket_id => ticket.display_id, :attributes => ticket.sbrr_attributes, :options => {:action => "reset_responder", :jid => self.jid}}
    SBRR::Execution.new(args).execute if ticket.eligible_for_round_robin?
  end
end
