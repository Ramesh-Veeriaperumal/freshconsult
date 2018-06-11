class UpdateTimeZone < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis

  sidekiq_options :queue => :update_time_zone, 
                  :retry => 3, 
                  :backtrace => true, 
                  :failures => :exhausted

  def perform args
    begin
      account = Account.current
      args.symbolize_keys!
      account.all_users.where('time_zone != ?', 
        args[:time_zone]).update_all_with_publish({ :time_zone => args[:time_zone] }, {})
    rescue => e 
      logger.info "Error when updating the time zone, args #{args.inspect}, error #{e.inspect}"
    ensure
      account.remove_time_zone_updation_redis
    end
  end
end
