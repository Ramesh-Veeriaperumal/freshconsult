class Helpdesk::ResetInternalGroup < BaseWorker

  sidekiq_options :queue => :reset_internal_group, :retry => 1, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    account             = Account.current
    internal_group_id   = args[:internal_group_id]
    status_id           = args[:status_id]
    internal_group_col  = Helpdesk::SchemaLessTicket.internal_group_column
    internal_agent_col  = Helpdesk::SchemaLessTicket.internal_agent_column
    options             = {:reason => args[:reason], :manual_publish => true}


    updates_hash = {internal_group_col => nil, internal_agent_col => nil}
    ids = Sharding.run_on_slave {
      account.schema_less_tickets.joins(:ticket).where(internal_group_col => internal_group_id,
        "helpdesk_tickets.status" => status_id).pluck(:id)
    }
    account.schema_less_tickets.where(:id => ids).update_all_with_publish(updates_hash, {}, options)

  rescue Exception => e
    puts e.inspect, args.inspect
    NewRelic::Agent.notice_error(e, {:args => args})
    raise e
  end

end
