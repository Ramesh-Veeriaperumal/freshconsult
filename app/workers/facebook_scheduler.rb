class FacebookScheduler < BaseWorker

  sidekiq_options :queue => :facebook_scheduler, :retry => 0, :backtrace => true, :failures => :exhausted
  
  def perform
    if empty_queue?(Social::FacebookWorker.get_sidekiq_options["queue"])
      logger.info "Facebook Worker initialized at #{Time.zone.now}"
      Sharding.run_on_all_slaves do
        Account.active_accounts.each do |account|
          Account.reset_current_account
          account.make_current
          next if account.facebook_pages.empty?
          Social::FacebookWorker.perform_async({:account_id => account.id})           
        end
      end
    else
      logger.info "Facebook Worker is already running . skipping at #{Time.zone.now}" 
    end
  end
end