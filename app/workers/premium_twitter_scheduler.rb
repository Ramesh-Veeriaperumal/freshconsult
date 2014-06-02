class PremiumTwitterScheduler < BaseWorker

  sidekiq_options :queue => :premium_twitter_scheduler, :retry => 0, :backtrace => true, :failures => :exhausted


  PREMIUM_ACCOUNT_IDS = { 
    :staging => [1], 
    :production => [18685,39190],
    :development => [1]
  }
  
  def perform
    premium_acc_ids = PREMIUM_ACCOUNT_IDS[Rails.env.to_sym]
    if empty_queue?(Social::PremiumTwitterWorker.get_sidekiq_options["queue"])
      premium_acc_ids.each do |account_id|
        Account.reset_current_account
        Account.find(account_id).make_current
        Social::PremiumTwitterWorker.perform_async({:account_id => account_id })
      end
    else
      logger.info "Premium Twitter Worker is already running . skipping at #{Time.zone.now}" 
    end
  end
end