class Helpdesk::ResetInternalGroup < BaseWorker

  include Redis::RedisKeys
  include Redis::OthersRedis
  
  sidekiq_options :queue => :reset_internal_group, :retry => 1, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    account             = Account.current
    internal_group_id   = args[:internal_group_id]
    status_id           = args[:status_id]
    options             = {:reason => args[:reason], :manual_publish => true}
    updates_hash        = {:internal_group_id => nil, :internal_agent_id => nil}

    tickets = nil
    Sharding.run_on_slave do
      tickets = account.tickets.where(:internal_group_id => internal_group_id, :status => status_id)
    end
    tickets.update_all_with_publish(updates_hash, {}, options)

  rescue Exception => e
    puts e.inspect, args.inspect
    NewRelic::Agent.notice_error(e, {:args => args})
    raise e
  end

end
