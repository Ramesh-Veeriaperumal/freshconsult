class Helpdesk::ResetGroup < BaseWorker

  sidekiq_options :queue => :reset_group, :retry => 0, :backtrace => true, :failures => :exhausted
  BATCH_LIMIT = 50

  def perform(args)
    begin
      args.symbolize_keys!
      account   = Account.current
      group_id  = args[:group_id]
      reason    = args[:reason].symbolize_keys!

      account.tickets.where(group_id: group_id).update_all_with_publish({ group_id: nil }, {})
      if account.features?(:shared_ownership)
        internal_group_col              = Helpdesk::SchemaLessTicket.internal_group_column
        internal_agent_col              = Helpdesk::SchemaLessTicket.internal_agent_column
        reason[:delete_internal_group]  = reason.delete(:delete_group)
        options                         = {:reason => reason, :manual_publish => true}
        updates_hash                    = {internal_group_col => nil, internal_agent_col => nil}

        account.schema_less_tickets.where(internal_group_col => group_id).update_all_with_publish(
          updates_hash, {}, options)
      end

      return unless account.features_included?(:archive_tickets)

      account.archive_tickets.where(group_id: group_id).update_all_with_publish({ group_id: nil }, {})

    rescue Exception => e
      puts e.inspect, args.inspect
      NewRelic::Agent.notice_error(e, {:args => args})
    end
  end

end
