class SlaScheduler < BaseWorker


  sidekiq_options :queue => :sla_scheduler, :retry => 0, :backtrace => true, :failures => :exhausted

  
  def perform
    logger.info "SLA escalation initiated at #{Time.zone.now}"
    custom_logger.info "rake=SLA" unless custom_logger.nil?
    current_time = Time.now.utc
    if empty_queue?(Admin::SlaWorker.get_sidekiq_options["queue"])
      accounts_queued = 0
      Sharding.run_on_all_slaves do
        Account.active_accounts.each do |account|
          Account.reset_current_account
          account.make_current       
          Admin::SlaWorker.perform_async({:account_id => account.id})
          accounts_queued += 1
        end
      end
      key = "stats:rake:sla:#{current_time.day}:#{current_time}"
      stats_redis_data(key,accounts_queued,144000)
    else
      key = "stats:rake:sla:#{current_time.day}:#{current_time}"
      stats_redis_data(key,"skipped",144000)
    end
    logger.info "SLA rule check completed at #{Time.zone.now}."
  end

  private
      def log_file
        @log_file_path ||= "#{Rails.root}/log/rake.log"      
      end
end