module Resque::AroundPerform

 def before_enqueue_add_account_and_user(*args)
    args[0][:account_id] = Account.current.id if Account.current  
    args[0][:current_user_id] = User.current.id if User.current
  end

  def before_perform_reset_account(*args)
    Account.reset_current_account
  end

 def on_failure_query_with_account_hash(exception,*args)
   unless self.respond_to?(:on_failure_query_with_args)
    case exception
    when TypeError
        Resque.enqueue(self.name.constantize, {:account_id => args[0]}) if args[0] and !args[0].is_a?(Hash)
    else
      puts "Do nothing"
   end
   end
 end

 def around_perform_with_shard(*args)
  args[0].symbolize_keys!
  account_id = (args[0][:account_id]) || (args[0][:current_account_id])
  ActiveRecord::Base.on_shard(shard_name.to_sym) do
    account = Account.find_by_id(account_id)
    account.make_current if account
      yield
  end
 end
end
