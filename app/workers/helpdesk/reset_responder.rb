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

      # Reset agent and internal agent for tickets
      account.tickets.where(responder_id: user.id).update_all_with_publish({ responder_id: nil }, {}, options)

      if account.features?(:shared_ownership)
        reason[:delete_internal_agent]  = reason.delete(:delete_agent)
        options                         = {:reason => reason, :manual_publish => true}
        updates_hash                    = {:internal_agent_id => nil}

        tickets = account.tickets.where(:internal_agent_id => user.id)
        ticket_ids = tickets.map(&:id)
        tickets.update_all_with_publish(updates_hash, {}, options)

        if redis_key_exists?(SO_FIELDS_MIGRATION)
          internal_agent_col  = "long_tc04"
          updates_hash        = {internal_agent_col => nil}

          account.schema_less_tickets.where(:ticket_id => ticket_ids).update_all_with_publish(
            updates_hash, {}, {})
        end
      end

      account.tickets.preload(:group).assigned_to(user).find_each do |ticket|
        ticket_ids.push(ticket.id) if ticket.group.present? && (ticket.group.capping_enabled? || ticket.group.skill_based_round_robin_enabled?)
      end

      account.tickets.where("id in (?)", ticket_ids).preload(:group).find_each do |ticket|
        if ticket.group.skill_based_round_robin_enabled?
          ticket.sbrr_fresh_ticket = true
          ticket.enqueue_skill_based_round_robin
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
end