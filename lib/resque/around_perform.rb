module Resque::AroundPerform

  def before_enqueue_job_watcher(*args)
    args[0][:enqueued_at] = Time.now if args[0].is_a?(Hash)
  end

 def before_enqueue_add_account_and_user(*args)
  if args[0].is_a?(Hash)
    args[0][:account_id] = Account.current.id if Account.current  
    args[0][:current_user_id] = User.current.id if User.current
  end
end

  def before_perform_reset_account(*args)
    Account.reset_current_account
  end

 def around_perform_with_shard(*args)
  params_hash = args[0].is_a?(Hash) ? args[0].symbolize_keys! : args[1].symbolize_keys!
  account_id = (params_hash[:account_id]) || (params_hash[:current_account_id])
  Sharding.select_shard_of(account_id) do
    ::NewRelic::Agent.trace_execution_scoped('Custom/Resque/around_perform_with_shard/find_by_id') do
      account = Account.find_by_id(account_id)
      if account
        account.make_current 
        # $statsd.increment "resque.#{@queue}.#{account.id}" 
      end
      TimeZone.set_time_zone
    end
    yield
  end
 end
end
