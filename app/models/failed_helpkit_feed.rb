class FailedHelpkitFeed < ActiveRecord::Base
  self.primary_key = :id
  not_sharded
  
	def requeue
		Sharding.select_shard_of(account_id) do
  		account = Account.find(account_id).make_current
  		RabbitmqWorker.perform_async(exchange.pluralize, payload, routing_key, Account.current.launched?(:lambda_exchange))
  		Account.reset_current_account
		end
	rescue ActiveRecord::RecordNotFound, ShardNotFound, DomainNotReady => e
		puts "#{e.inspect} -- #{account_id}"
	end
end