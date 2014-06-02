class TwitterScheduler < BaseWorker

  sidekiq_options :queue => :twitter_scheduler, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform
    if empty_queue?(Social::TwitterWorker.get_sidekiq_options["queue"])
        logger.info "Twitter Queue is empty... queuing at #{Time.zone.now}"
        Sharding.run_on_all_slaves do
         Account.active_accounts.non_premium_accounts.each do |account|  
          next if account.twitter_handles.empty?
          Account.reset_current_account
          account.make_current
          Social::TwitterWorker.perform_async({:account_id => account.id })
         end
        end
    else
      logger.info "Twitter Queue is already running . skipping at #{Time.zone.now}"  
    end
    logger.info "Twitter task closed at #{Time.zone.now}"
  end
end