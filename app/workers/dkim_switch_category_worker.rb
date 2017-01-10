class DkimSwitchCategoryWorker

  include Sidekiq::Worker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Dkim::UtilityMethods

  sidekiq_options :queue => :dkim_general, :retry => 5, :backtrace => true, :failures => :exhausted
  
  sidekiq_retry_in do |count|
    (count+15).minutes
  end
  
  sidekiq_retries_exhausted do |msg|
    Sidekiq.logger.warn "Failed #{msg['class']} with #{msg['args']}: #{msg['error_message']}"
    Dkim::UserNotification.new.notify_dev(msg)
  end

  def perform(args)
    args.symbolize_keys!
    return if args[:account_id].blank? or args[:record_id].blank? or args[:activity_id].blank?
    execute_on_master(args[:account_id], args[:record_id]){
      unless Dkim::CategoryChanger.new(@domain_category).switch_email_domains(args[:activity_id])
        raise "Dkim::CategoryChanger failed. domain_category ::: #{domain_category.inspect} args ::: #{args.inspect}"
      end
      Account.reset_current_account
    }
  end
end 

