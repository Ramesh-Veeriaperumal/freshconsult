module Social
  class PremiumTwitterWorker < Social::TwitterWorker
    
    sidekiq_options :queue => :premium_twitter, :retry => 0, :backtrace => true, :failures => :exhausted
    
    def perform(args)
      Rails.logger.debug "Premium Twitter Worker starting at #{Time.now} for account #{args['account_id']}"
      Sharding.select_shard_of(args['account_id']) do
        Account.find(args['account_id']).make_current
        super({})
      end
      rescue ActiveRecord::RecordNotFound, ActiveRecord::AdapterNotSpecified, ShardNotFound => e
        Rails.logger.debug "#{e.inspect} -- #{args['account_id']}"
    end
    
  end
end
