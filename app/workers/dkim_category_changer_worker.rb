class DkimCategoryChangerWorker

  include Sidekiq::Worker
  include Redis::RedisKeys
  include Redis::OthersRedis

  sidekiq_options :queue => :dkim_general, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform
    account = Account.current
    account.outgoing_email_domain_categories.dkim_activated_domains.each_with_index do |domain_category, index|
      Rails.logger.debug("domain_category ::: #{domain_category.inspect} index :: #{index}")
      activity_id = Dkim::CategoryChanger.new(domain_category, index).change_records
      Rails.logger.debug("activity_id ::: #{activity_id}")
      DkimSwitchCategoryWorker.perform_at(15.minutes.from_now, {:account_id => account.id, 
      :record_id => domain_category.id, :activity_id => activity_id}) if activity_id
    end
    get_others_redis_lrem(DKIM_CATEGORY_KEY, account.id) 
    Account.reset_current_account   
  rescue Exception => e
    msg = {'class' => e.class, 'args' => e.exception.to_s, 'error_message' => e.backtrace}
    Dkim::UserNotification.new.notify_dev(msg)
  end
end 

