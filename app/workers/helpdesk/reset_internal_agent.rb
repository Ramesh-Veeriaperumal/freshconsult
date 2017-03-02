class Helpdesk::ResetInternalAgent < BaseWorker 

  include Redis::RedisKeys
  include Redis::OthersRedis

  sidekiq_options :queue => :reset_internal_agent, :retry => 1, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    account             = Account.current
    internal_group_id   = args[:internal_group_id]
    internal_agent_id   = args[:internal_agent_id]
    options             = {:reason => args[:reason], :manual_publish => true}

    updates_hash = {:internal_agent_id => nil}
    tickets = account.tickets.where(:internal_group_id => internal_group_id, 
      :internal_agent_id => internal_agent_id)
    ticket_ids = tickets.map(&:id)
    tickets.update_all_with_publish(updates_hash, {}, options)
    

    if redis_key_exists?(SO_FIELDS_MIGRATION)
      internal_group_col  = "long_tc03"
      internal_agent_col  = "long_tc04"
      updates_hash = {internal_agent_col => nil}
      account.schema_less_tickets.where(:ticket_id => ticket_ids).update_all_with_publish(updates_hash, {}, {})
    end

  rescue Exception => e
    puts e.inspect, args.inspect
    NewRelic::Agent.notice_error(e, {:args => args})
    raise e
  end

end