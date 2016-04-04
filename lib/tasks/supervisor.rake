def log_file
    @log_file_path = "#{Rails.root}/log/rake.log"      
end 

def custom_logger(path)
    @custom_logger||=CustomLogger.new(path)
end

SUPERVISOR_TAKS = {
                   
                   "trial" => {:account_method => "trial_accounts", :queue_name => "trial_supervisor_worker",
                   :class_name => "Workers::Supervisor::TrialAccounts"},
                   
                   "paid" => {:account_method => "paid_accounts", :queue_name => "supervisor_worker",
                   :class_name => "Workers::Supervisor"},
                   
                   "free" => {:account_method => "free_accounts", :queue_name => "free_supervisor_worker",
                   :class_name => "Workers::Supervisor::FreeAccounts"}
                  
                  }

namespace :supervisor do

  desc 'Execute Supervisor Rules for paid accounts'
  task :run => :environment do
    execute_supevisor("paid")
  end

  desc 'Execute Supervisor Rules for trial accounts'
  task :trial => :environment do
   execute_supevisor("trial")
  end

  desc 'Execute Supervisor Rules for free accounts'
  task :free => :environment do
   execute_supevisor("free")
  end

  desc 'Execute Supervisor Rules for premium accounts'
  task :premium => :environment do
    queue_name = "premium_supervisor_worker"
    if supervisor_should_run?(queue_name)
        #Monitoring::RecordMetrics.register({:task_name => "Supervisor Premium"})
        Sharding.execute_on_all_shards do
          Account.current_pod.active_accounts.premium_accounts.each do |account|
            if account.supervisor_rules.count > 0 
              Resque.enqueue(Workers::Supervisor::PremiumSupervisor, {:account_id => account.id })
            end
          end
        end
    end
  end
end

def execute_supevisor(task_name)
  spam_account_ids = [179222, 26084]
  if supervisor_should_run?(SUPERVISOR_TAKS[task_name][:queue_name])
    puts "#{Time.now.strftime("%Y-%d-%m %H:%M:%S")}  rake=#{task_name} Supervisor got triggered"
    accounts_queued = 0
    begin
      path = log_file
      rake_logger = custom_logger(path)
    rescue Exception => e
      puts "Error occured #{e}" 
      FreshdeskErrorsMailer.error_email(nil,nil,e,{:subject => "Splunk logging Error for supervisor.rake",:recipients => "pradeep.t@freshdesk.com"})       
    end    
    rake_logger.info "rake=#{task_name} Supervisor" unless rake_logger.nil?
    Sharding.execute_on_all_shards do
      Account.send(SUPERVISOR_TAKS[task_name][:account_method]).current_pod.non_premium_accounts.each do |account|         
        if account.supervisor_rules.count > 0 
          if spam_account_ids.include?(account.id) and Rails.env.production?
            Resque.enqueue(SUPERVISOR_TAKS["free"][:class_name].constantize, {:account_id => account.id })            
          else
            Resque.enqueue(SUPERVISOR_TAKS[task_name][:class_name].constantize, {:account_id => account.id })            
          end
          accounts_queued += 1
        end
      end
    end
  end
end

def supervisor_should_run?(queue_name)
  queue_length = Resque.redis.llen "queue:#{queue_name}"
  puts "#{queue_name} queue length is #{queue_length}"
  if queue_length < 1 and !Rails.env.staging?
    true
  else
    subject = "Supervisor skipped for #{queue_name} at #{Time.now.utc.to_s} in #{Rails.env}"
    message = "Queue Name = #{queue_name}\nQueue Length = #{queue_length}"
    DevNotification.publish(SNS["dev_ops_notification_topic"], subject, message)
    false
  end
end

