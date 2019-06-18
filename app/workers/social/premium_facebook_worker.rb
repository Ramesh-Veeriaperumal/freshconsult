module Social
  class PremiumFacebookWorker < Social::FacebookWorker
    sidekiq_options queue: :premium_facebook, retry: 0, failures: :exhausted

    def perform(args)
      Rails.logger.debug "Premium Facebook Worker starting at #{Time.now.utc} for account #{args['account_id']}"
      Sharding.select_shard_of(args['account_id']) do
        Account.find(args['account_id']).make_current
        super({})
      end
    rescue ActiveRecord::RecordNotFound, ActiveRecord::AdapterNotSpecified, ShardNotFound => e
      Rails.logger.debug "#{e.inspect} -- #{args['account_id']}"
    end
  end
end
