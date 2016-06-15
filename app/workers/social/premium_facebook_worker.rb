module Social
  class PremiumFacebookWorker < Social::FacebookWorker
    
    
    sidekiq_options :queue => :premium_facebook, :retry => 0, :backtrace => true, :failures => :exhausted
    
    def perform(args)
      Sharding.select_shard_of(args['account_id']) do
        Account.find(args['account_id']).make_current
        super({})
      end
      rescue ActiveRecord::RecordNotFound, ShardNotFound => e
        Rails.logger.debug "#{e.inspect} -- #{args['account_id']}"
    end
    
  end
end
