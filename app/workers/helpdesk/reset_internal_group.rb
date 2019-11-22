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

    condition = { internal_group_id: internal_group_id }
    condition[:status] = status_id if status_id

    account.tickets.where(condition).update_all_with_publish(updates_hash, {}, options)
  rescue Exception => e
    NewRelic::Agent.notice_error(e, {:args => args})
    raise e
  end

end
