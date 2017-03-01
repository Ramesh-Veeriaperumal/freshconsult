require 'sidekiq/api'
namespace :scheduler do

  SUPERVISOR_TASKS = {
    "trial" => { 
      :account_method => "trial_accounts", 
      :class_name     => "Admin::TrialSupervisorWorker"
    },
    "paid" => {
      :account_method => "paid_accounts", 
      :class_name     => "Admin::SupervisorWorker"
    },
    "free" => {
      :account_method => "free_accounts",
      :class_name     => "Admin::FreeSupervisorWorker"
    },
    "premium" => {
      :account_method => "active_accounts",
      :class_name     => "Admin::PremiumSupervisorWorker"
    }
  }

  SLA_REMINDER_TASKS = {
    "trial" => {
      :account_method => "trial_accounts", 
      :class_name => "Admin::Sla::Reminder::Trial"
    },

    "paid" => {
      :account_method => "paid_accounts", 
      :class_name => "Admin::Sla::Reminder::Base"
    },

    "free" => {
      :account_method => "free_accounts", 
      :class_name => "Admin::Sla::Reminder::Free"
    },

    "premium" => {
      :account_method => "active_accounts",
      :class_name => "Admin::Sla::Reminder::Premium"
    }
  }  

  SLA_TASKS = {
    "trial" => {
      :account_method => "trial_accounts", 
      :class_name => "Admin::Sla::Escalation::Trial"
    },

    "paid" => {
      :account_method => "paid_accounts", 
      :class_name => "Admin::Sla::Escalation::Base"
    },

    "free" => {
      :account_method => "free_accounts", 
      :class_name => "Admin::Sla::Escalation::Free"
    },

    "premium" => {
      :account_method => "active_accounts",
      :class_name => "Admin::Sla::Escalation::Premium"
    }
  }

  FACEBOOK_TASKS = {
    "trial" => { 
      :account_method => "trail_acc_pages", 
      :class_name     => "Social::TrialFacebookWorker"
    },
    "paid" => {
      :account_method => "paid_acc_pages", 
      :class_name     => "Social::FacebookWorker"
    }
  }
  
  TWITTER_TASKS = {
    "trial" => { 
      :account_method => "trail_acc_handles", 
      :class_name     => "Social::TrialTwitterWorker"
    },
    "paid" => {
      :account_method => "paid_acc_handles", 
      :class_name     => "Social::TwitterWorker"
    }
  }

  PREMIUM_ACCOUNT_IDS_FB = {
      "development" => [1],
      "staging"     => [390], 
      "production"  => [79003, 309357, 39190, 19063, 86336, 34388, 126077, 220561, 166928, 254067, 381984, 470840]
  }

  PREMIUM_ACCOUNT_IDS_TWT = {
    "development" => [1],
    "staging"     => [390], 
    "production"  => [79003, 309357, 39190, 19063, 86336, 34388, 126077, 220561, 166928, 254067, 381984]
  }

  def log_file
    @log_file_path = "#{Rails.root}/log/rake.log"      
  end 

  def rake_logger
    begin
      path = log_file
      rake_logger ||= CustomLogger.new(log_file)
    rescue Exception => e
      puts "Error occured #{e}"  
      FreshdeskErrorsMailer.error_email(nil,nil,e,{
        :subject => "Splunk logging Error for rake", 
        :recipients => (Rails.env.production? ? Helpdesk::EMAIL[:production_dev_ops_email] : "dev-ops@freshpo.com")
        })      
    end
  end

  def empty_queue?(queue_name)
    queue_length = Sidekiq::Queue.new(queue_name).size
    puts "#{queue_name} queue length is #{queue_length}"
    #queue_length === 0 and !Rails.env.staging?
    if queue_length < 1 and !Rails.env.staging?
      true
    else
      subject = "Scheduler skipped for #{queue_name} at #{Time.now.utc.to_s} in #{Rails.env}"
      message = "Queue Name = #{queue_name}\nQueue Length = #{queue_length}"
      DevNotification.publish(SNS["dev_ops_notification_topic"], subject, message)
      false
    end
  end

  def enqueue_automation(name, task_name, premium_constant = "non_premium_accounts")
    automation = case name
      when "supervisor" 
         SUPERVISOR_TASKS
      when "sla_reminder"
        SLA_REMINDER_TASKS
      when "sla_escalation"
        SLA_TASKS
    end
    return if automation.nil?

    class_constant = automation[task_name][:class_name].constantize
    queue_name = class_constant.get_sidekiq_options["queue"]
    puts "::::queue_name:::#{queue_name}"
    premium_constant = "premium_accounts" if task_name.eql?("premium")
    
    if empty_queue?(queue_name)
      rake_logger.info "rake=#{task_name} #{name}" unless rake_logger.nil?
      accounts_queued = 0
      Sharding.run_on_all_slaves do
        Account.send(automation[task_name][:account_method]).current_pod.send(premium_constant).each do |account|
          begin
            account.make_current
            if name.eql?("supervisor")
              class_constant.perform_async if account.supervisor_enabled? &&
                                              account.supervisor_rules.count > 0
            else
              class_constant.perform_async if account.sla_management_enabled?
            end
            accounts_queued +=1
          rescue Exception => e
            NewRelic::Agent.notice_error(e)
          ensure
            Account.reset_current_account  
          end
        end
      end
    end
  end
  
  def enqueue_facebook(task_name)
    class_constant = FACEBOOK_TASKS[task_name][:class_name].constantize
    queue_name = class_constant.get_sidekiq_options["queue"]
    puts "::::Queue Name::: #{queue_name}"
    if empty_queue?(queue_name)
      Sharding.run_on_all_slaves do
        Account.reset_current_account
        Social::FacebookPage.current_pod.send(FACEBOOK_TASKS[task_name][:account_method]).each do |fb_page|
          Account.reset_current_account
          account = fb_page.account
          next unless account
          account.make_current
          next if (check_if_premium?(account, PREMIUM_ACCOUNT_IDS_FB) || !fb_page.valid_page?)
          class_constant.perform_async({:fb_page_id => fb_page.id}) 
        end
      end
    else
      puts "Facebook Worker is already running . skipping at #{Time.zone.now}" 
    end
  end
  
  def enqueue_twitter(task_name)
    class_constant = TWITTER_TASKS[task_name][:class_name].constantize
    queue_name = class_constant.get_sidekiq_options["queue"]
    puts "::::Queue Name::: #{queue_name}"
    if empty_queue?(queue_name)
      Sharding.run_on_all_slaves do
        Account.reset_current_account
        Social::TwitterHandle.current_pod.send(TWITTER_TASKS[task_name][:account_method]).each do |twitter_handle|
          Account.reset_current_account
          account = twitter_handle.account
          next unless account
          account.make_current
          next if (check_if_premium?(account, PREMIUM_ACCOUNT_IDS_TWT) || !twitter_handle.capture_dm_as_ticket)
          class_constant.perform_async({:twt_handle_id => twitter_handle.id}) 
        end
      end
    else
      puts "Twitter Worker is already running . skipping at #{Time.zone.now}" 
    end
  end
  
  def enqueue_premium_twitter(delay = nil)
    PREMIUM_ACCOUNT_IDS_TWT["#{Rails.env}"].each do |account_id|
      if delay.nil?
        Social::PremiumTwitterWorker.perform_async({:account_id => account_id})
      else
        Social::PremiumTwitterWorker.perform_in(delay, {:account_id => account_id})
      end
    end
  end
  
  def enqueue_premium_facebook(delay = nil)
    PREMIUM_ACCOUNT_IDS_FB["#{Rails.env}"].each do |account_id|
      if delay.nil?
        Social::PremiumFacebookWorker.perform_async({:account_id => account_id})
      else
        Social::PremiumFacebookWorker.perform_in(delay, {:account_id => account_id})
      end
    end
  end
  
  def check_if_premium?(account, premium_accounts)
    premium_accounts["#{Rails.env}"].include?(account.id)
  end

  task :supervisor, [:type] => :environment do |t,args|
    account_type = args.type || "paid"
    puts "Running #{account_type} supervisor initiated at #{Time.zone.now}"
    enqueue_automation("supervisor", account_type)
    puts "Running #{account_type} supervisor completed at #{Time.zone.now}"
  end

  task :sla, [:type] => :environment do |t,args|
    account_type = args.type || "paid"
    puts "SLA escalation initiated at #{Time.zone.now}"
    enqueue_automation("sla_escalation", account_type)
    puts "SLA rule check completed at #{Time.zone.now}."
  end
  
  task :sla_reminder, [:type] => :environment do |t,args|
    account_type = args.type || "paid"
    puts "SLA Reminder escalation initiated at #{Time.zone.now}"
    enqueue_automation("sla_reminder", account_type)
    puts "SLA Reminder rule check completed at #{Time.zone.now}."
  end


  desc 'Fetch facebook feeds and direct messages'
  task :facebook, [:type] => :environment do |t,args|
    account_type = args.type || "paid"
    puts "Running #{account_type} facebook worker initiated at #{Time.zone.now}"
    if account_type == "paid"
      enqueue_premium_facebook
      enqueue_premium_facebook(2.minutes)
      enqueue_premium_facebook(4.minutes)
    end
    enqueue_facebook(account_type)
    puts "Running #{account_type} facebook worker completed at #{Time.zone.now}"
  end
  
  desc 'Fetch twitter direct messages'
  task :twitter, [:type] => :environment do |t,args|
    account_type = args.type || "paid"
    puts "Running #{account_type} twitter worker initiated at #{Time.zone.now}"
    if account_type == "paid"
      enqueue_premium_twitter
      enqueue_premium_twitter(2.minutes)
      enqueue_premium_twitter(4.minutes)
    end
    enqueue_twitter(account_type)
    puts "Running #{account_type} twitter worker completed at #{Time.zone.now}"
  end
  
  desc "Fetch custom twitter streams"
  task :custom_stream_twitter => :environment do
    if empty_queue?(Social::CustomTwitterWorker.get_sidekiq_options["queue"])
      puts "Twitter Queue is empty... queuing at #{Time.zone.now}"
      Sharding.run_on_all_slaves do
        Account.current_pod.active_accounts.each do |account|
          Account.reset_current_account
          account.make_current
          next if account.twitter_handles.empty?
          Social::CustomTwitterWorker.perform_async
        end
       end
     else
      puts "Custom Stream Worker is already running . skipping at #{Time.zone.now}" 
     end
  end

  desc "Twitter replay worker"
  task :gnip_replay => :environment do
    disconnect_list = Social::Twitter::Constants::GNIP_DISCONNECT_LIST
    $redis_others.perform_redis_op("lrange", disconnect_list, 0, -1).each do |disconnected_period|
      period = JSON.parse(disconnected_period)
      if period[0] && period[1]
        
        end_time = DateTime.strptime(period[1], '%Y%m%d%H%M').to_time
        difference_in_seconds = (Time.now.utc - end_time).to_i
        
        if difference_in_seconds > Social::Twitter::Constants::TIME[:replay_stream_wait_time]
          args = {:start_time => period[0], :end_time => period[1]}
          puts "Gonna initialize ReplayStreamWorker #{Time.zone.now}"
          Social::TwitterReplayStreamWorker.perform_async(args)
          $redis_others.perform_redis_op("lrem", disconnect_list, 1, disconnected_period)
        end
      end
    end
  end
  
end
