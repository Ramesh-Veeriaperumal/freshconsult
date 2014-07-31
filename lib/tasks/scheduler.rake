require 'sidekiq/api'
namespace :scheduler do


  SUPERVISOR_TASKS = {
    "trial" => { 
      :account_method => "trial_accounts", 
      :class_name => "Admin::TrialSupervisorWorker"
    },
    "paid" => {
      :account_method => "paid_accounts", 
      :class_name => "Admin::SupervisorWorker"
    },
    "free" => {
      :account_method => "free_accounts",
      :class_name => "Admin::FreeSupervisorWorker"
    },
    "premium" => {
      :account_method => "premium_accounts",
      :class_name => "Admin::PremiumSupervisorWorker"
    }
  }


  SLA_TASKS = {
    "trial" => {
      :account_method => "trial_accounts", 
      :class_name => "Admin::TrialSlaWorker"
    },

    "paid" => {
      :account_method => "paid_accounts", 
      :class_name => "Admin::SlaWorker"
    },

    "free" => {
      :account_method => "free_accounts", 
      :class_name => "Admin::FreeSlaWorker"
    }

  }

  PREMIUM_ACCOUNT_IDS = {:staging => [390,1010001453,1010001456], :production => [18685,39190,19063,86336,34388,126077]}


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
    queue_length === 0 and !Rails.env.staging?
  end


  def enqueue_supevisor(task_name, premium_constant = "non_premium_accounts")
    class_constant = SUPERVISOR_TASKS[task_name][:class_name].constantize
    queue_name = class_constant.get_sidekiq_options["queue"]
    puts "::::queue_name:::#{queue_name}"
    premium_constant = "premium_accounts" if task_name.eql?("premium")
    current_time = Time.now.utc
    if empty_queue?(queue_name)
      rake_logger.info "rake=#{task_name} Supervisor" unless rake_logger.nil?
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
    end
  end

  task :supervisor, [:type] => :environment do |t,args|
    account_type = args.type || "paid"
    puts "Running #{account_type} supervisor initiated at #{Time.zone.now}"
    enqueue_supevisor(account_type)
    puts "Running #{account_type} supervisor completed at #{Time.zone.now}"
  end

  task :sla, [:type] => :environment do |t,args|
    account_type = args.type || "paid"
    class_constant = SLA_TASKS[account_type][:class_name].constantize
    queue_name = class_constant.get_sidekiq_options["queue"]
    puts "::::queue_name:::#{queue_name}"
    puts "SLA escalation initiated at #{Time.zone.now}"
    rake_logger.info "rake= #{account_type} SLA" unless rake_logger.nil?
    current_time = Time.now.utc
    if empty_queue?(queue_name)
      accounts_queued = 0
      Sharding.run_on_all_slaves do
        Account.send(SLA_TASKS[account_type][:account_method]).each do |account| 
          Account.reset_current_account
          account.make_current       
          class_constant.perform_async({ 
            :account_id => account.id
          })
          accounts_queued += 1
        end
      end
    end
    puts "SLA rule check completed at #{Time.zone.now}."
  end


  task :facebook => :environment do
    if empty_queue?(Social::FacebookWorker.get_sidekiq_options["queue"])
      puts "Facebook Worker initialized at #{Time.zone.now}"
      Sharding.run_on_all_slaves do
        Account.active_accounts.each do |account|
          Account.reset_current_account
          account.make_current
          next if account.facebook_pages.empty?
          Social::FacebookWorker.perform_async({:account_id => account.id})           
        end
      end
    else
      puts "Facebook Worker is already running . skipping at #{Time.zone.now}" 
    end
  end


  task :premium_facebook => :environment do
    premium_acc_ids = Rails.env.production? ? PREMIUM_ACCOUNT_IDS[:production] : PREMIUM_ACCOUNT_IDS[:staging]
    if empty_queue?(Social::PremiumFacebookWorker.get_sidekiq_options["queue"])
      premium_acc_ids.each do |account_id|
        Sharding.select_shard_of(account_id) do
          Account.reset_current_account
          Account.find(account_id).make_current
          Social::PremiumFacebookWorker.perform_async({:account_id => account_id })
        end
      end
    else
      puts "Premium Facebook Worker is already running . skipping at #{Time.zone.now}" 
    end
  end


  task :facebook_comments => :environment do
    if empty_queue?(Social::FbCommentsWorker.get_sidekiq_options["queue"])
      puts "Facebook Comments Worker initialized at #{Time.zone.now}"
      shards = Sharding.all_shards
      shards.each do |shard_name|
        shard_sym = shard_name.to_sym
        puts "shard_name is #{shard_name}"
        Sharding.run_on_shard(shard_name) do
          Account.reset_current_account
          Sharding.run_on_slave do
            Social::FacebookPage.active.find_in_batches( 
              :joins => %(
                LEFT JOIN  accounts on accounts.id = social_facebook_pages.account_id 
                INNER JOIN `subscriptions` ON subscriptions.account_id = accounts.id),
              :conditions => "subscriptions.next_renewal_at > now() "
            ) do |page_block|
              page_block.each do |page|
                Account.reset_current_account
                page.account.make_current
                  Social::FbCommentsWorker.perform_async({
                    :account_id => page.account_id, 
                    :fb_page_id => page.id
                  })
                Account.reset_current_account 
              end          
            end
          end
        end
      end
    else
      puts "Facebook Comments Worker is already running . skipping at #{Time.zone.now}" 
    end
  end

  task :twitter => :environment do    
    if empty_queue?(Social::TwitterWorker.get_sidekiq_options["queue"])
        puts "Twitter Queue is empty... queuing at #{Time.zone.now}"
        Sharding.run_on_all_slaves do
         Account.active_accounts.each do |account|  
          Account.reset_current_account
          account.make_current
          next if account.twitter_handles.empty?
          Social::TwitterWorker.perform_async({:account_id => account.id })
         end
        end
    else
      puts "Twitter Queue is already running . skipping at #{Time.zone.now}"  
    end
    puts "Twitter task closed at #{Time.zone.now}"
  end

  task :premium_twitter => :environment do
    premium_acc_ids = Rails.env.production? ? PREMIUM_ACCOUNT_IDS[:production] : PREMIUM_ACCOUNT_IDS[:staging]
    if empty_queue?(Social::PremiumTwitterWorker.get_sidekiq_options["queue"])
      premium_acc_ids.each do |account_id|
        Account.reset_current_account
        Account.find(account_id).make_current
        Social::PremiumTwitterWorker.perform_async({:account_id => account_id })
      end
    else
      puts "Premium Twitter Worker is already running . skipping at #{Time.zone.now}" 
    end
  end

  task :gnip_replay => :environment do
    disconnect_list = Social::Twitter::Constants::GNIP_DISCONNECT_LIST
    $redis_others.lrange(disconnect_list, 0, -1).each do |disconnected_period|
      period = JSON.parse(disconnected_period)
      if period[0] && period[1]
        
        end_time = DateTime.strptime(period[1], '%Y%m%d%H%M').to_time
        difference_in_seconds = (Time.now.utc - end_time).to_i
        
        if difference_in_seconds > Social::Twitter::Constants::TIME[:replay_stream_wait_time]
          args = {:start_time => period[0], :end_time => period[1]}
          puts "Gonna initialize ReplayStreamWorker #{Time.zone.now}"
          Social::TwitterReplyStreamWorker.perform_async(args)
          $redis_others.lrem(disconnect_list, 1, disconnected_period)
        end
      end
    end
  end

end