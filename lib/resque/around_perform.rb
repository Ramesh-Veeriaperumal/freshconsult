module Resque::AroundPerform

 def before_enqueue_add_account_and_user(*args)
    args[0][:account_id] = Account.current.id if Account.current  
    args[0][:current_user_id] = User.current.id if User.current
  end

  def before_perform_reset_account(*args)
    Account.reset_current_account
  end

 def around_perform_with_shard(*args)
  params_hash = args[0].is_a?(Hash) ? args[0].symbolize_keys! : args[1].symbolize_keys!
  account_id = (params_hash[:account_id]) || (params_hash[:current_account_id])
  Sharding.select_shard_of(account_id) do
    account = Account.find_by_id(account_id)
    account.make_current if account
    time_spent = Benchmark.realtime {yield}
    Monitoring::RecordMetrics.performance_data({:class_name => self.name, :time_spent => time_spent, :account_id => account_id })  
  end
 end
end
