class DkimRecordVerificationWorker

  include Sidekiq::Worker
  include Dkim::Methods
  include Dkim::UtilityMethods
  
  MAX_INTERVAL_MINUTES = 240

  sidekiq_options :queue => :dkim_verifier, :retry => 15, :backtrace => true, :failures => :exhausted
  
  sidekiq_retry_in do |count|
    next_retry = ((count+1)*30 > MAX_INTERVAL_MINUTES ? MAX_INTERVAL_MINUTES : (count+1)*30)
    next_retry.minutes
  end
  
  sidekiq_retries_exhausted do |msg|
    Dkim::UserNotification.new.notify_user(msg['args'][0])
    Dkim::UserNotification.new.notify_dev(msg)
    Sidekiq.logger.warn "Failed #{msg['class']} with #{msg['args']}: #{msg['error_message']}"
  end

  def perform(args)
    args.symbolize_keys!
    Rails.logger.debug("In Verification worker :: #{args.inspect} #{'*'*100}")
    return if args[:account_id].blank? or args[:record_id].blank?
    execute_on_master(args[:account_id], args[:record_id]){
      return remove_others_redis_key(dkim_verify_key(@domain_category)) if @domain_category.dkim_records.count.zero?
      Dkim::ValidateDkimRecord.new(@domain_category).validate
      raise "Dkim Record verification failed" if @domain_category.status != OutgoingEmailDomainCategory::STATUS['active']
      send_email unless args[:source] == 'category_worker'
    }
  end

  private
    def send_email
      if redis_key_exists?(dkim_verify_key(@domain_category))
        remove_others_redis_key(dkim_verify_key(@domain_category))
        if @domain_category.status == OutgoingEmailDomainCategory::STATUS['active']
          UserNotifier.notify_dkim_activation(Account.current, @domain_category.attributes)
        end
      end
    end
end 

