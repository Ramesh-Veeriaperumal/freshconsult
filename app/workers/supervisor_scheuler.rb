class SupervisorScheduler < BaseWorker

  sidekiq_options :queue => :supervisor_scheduler, :retry => 0, :backtrace => true, :failures => :exhausted


  SUPERVISOR_TASKS = {
    :trial => { 
      :account_method => "trial_accounts", 
      :class_name => "Admin::TrialSupervisorWorker"
    },
    :paid => {
      :account_method => "paid_accounts", 
      :class_name => "Admin::SupervisorWorker"
    },
    :free => {
      :account_method => "free_accounts",
      :class_name => "Admin::FreeSupervisorWorker"
    },
    :premium => {
      :account_method => "premium_accounts",
      :class_name => "Admin::PremiumSupervisorWorker"
    }
  }

  
  def perform
    SUPERVISOR_TASKS.keys.each do |task_name|
      schedule(task_name)
    end
  end

  protected
      def log_file
        @log_file_path ||= "#{Rails.root}/log/rake.log"      
      end

      def schedule(task_name, premium_constant = "non_premium_accounts")
        class_constant = SUPERVISOR_TASKS[task_name][:class_name].constantize
        queue_name = class_constant.get_sidekiq_options["queue"]
        logger.info "::::queue_name:::#{queue_name}"
        premium_constant = "premium_accounts" if task_name.eql?(:premium)
        current_time = Time.now.utc
        if empty_queue?(queue_name)
          custom_logger.info "rake=#{task_name} Supervisor" unless custom_logger.nil?
          accounts_queued = 0
          Sharding.run_on_all_slaves do
            Account.send(SUPERVISOR_TASKS[task_name][:account_method]).send(premium_constant).each do |account| 
              account.make_current
              if account.supervisor_rules.count > 0 
                class_constant.perform_async({ 
                  :account_id => account.id
                }) if account.supervisor_rules.count > 0
              end
              Account.reset_current_account
              accounts_queued +=1
            end
          end
          key = "stats:rake:supervisor_#{task_name}:#{current_time.day}:#{current_time}"
          stats_redis_data(key,accounts_queued,144000)
        else
          key = "stats:rake:supervisor_#{task_name}:#{current_time.day}:#{current_time}"
          stats_redis_data(key,"skipped",144000)
        end
      end
end