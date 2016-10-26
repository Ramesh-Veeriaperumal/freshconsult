class Helpdesk::ResetInternalAgent < BaseWorker 

  sidekiq_options :queue => :reset_internal_agent, :retry => 1, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    account             = Account.current
    internal_group_id   = args[:internal_group_id]
    internal_agent_id   = args[:internal_agent_id]
    internal_group_col  = Helpdesk::SchemaLessTicket.internal_group_column
    internal_agent_col  = Helpdesk::SchemaLessTicket.internal_agent_column
    options             = {:reason => args[:reason], :manual_publish => true}

    updates_hash = {internal_agent_col => nil}
    account.schema_less_tickets.where(internal_group_col => internal_group_id, 
      internal_agent_col => internal_agent_id).update_all_with_publish(updates_hash, {}, options)

  rescue Exception => e
    puts e.inspect, args.inspect
    NewRelic::Agent.notice_error(e, {:args => args})
    raise e
  end

end