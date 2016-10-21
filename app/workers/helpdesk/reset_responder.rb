class Helpdesk::ResetResponder < BaseWorker

  sidekiq_options :queue => :reset_responder, :retry => 0, :backtrace => true, :failures => :exhausted
  BATCH_LIMIT = 50

  def perform(args)
    begin
      args.symbolize_keys!
      account   = Account.current
      user_id   = args[:user_id]
      user      = account.all_users.find_by_id(user_id)
      reason    = args[:reason].symbolize_keys!
      return if user.nil?
      ticket_ids = []

      account.tickets.preload(:group).assigned_to(user).find_each do |ticket|
        ticket_ids.push(ticket.id) if ticket.group.present? && ticket.group.capping_enabled?
      end

      account.tickets.where(responder_id: user.id).update_all_with_publish({ responder_id: nil }, {})
      if account.features?(:shared_ownership)
        internal_agent_col              = Helpdesk::SchemaLessTicket.internal_agent_column
        reason[:delete_internal_agent]  = reason.delete(:delete_agent)
        options                         = {:reason => reason, :manual_publish => true}
        updates_hash                    = {internal_agent_col => nil}

        account.schema_less_tickets.where(internal_agent_col => user.id).update_all_with_publish(
          updates_hash, {}, options)
      end

      account.tickets.where("id in (?)", ticket_ids).find_each do |ticket|
        ticket.assign_tickets_to_agents
      end

      return unless account.features_included?(:archive_tickets)

      account.archive_tickets.where(responder_id: user.id).update_all_with_publish({ responder_id: nil }, {})

    rescue Exception => e
      puts e.inspect, args.inspect
      NewRelic::Agent.notice_error(e, {:args => args})
    end
  end
end