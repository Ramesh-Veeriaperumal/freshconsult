class Helpdesk::ResetInternalAgent < BaseWorker 

  include Redis::RedisKeys
  include Redis::OthersRedis

  sidekiq_options :queue => :reset_internal_agent, :retry => 1, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    account             = Account.current
    internal_group_id   = args[:internal_group_id]
    internal_agent_id   = args[:internal_agent_id]
    options             = {:reason => args[:reason], :manual_publish => true}
    updates_hash        = { internal_agent_id: nil }

    condition = { internal_agent_id: internal_agent_id }
    condition[:internal_group_id] = internal_group_id if internal_group_id

    account.tickets.where(condition).update_all_with_publish(updates_hash, {}, options)
  rescue Exception => e
    NewRelic::Agent.notice_error(e, {:args => args})
    raise e
  end

end