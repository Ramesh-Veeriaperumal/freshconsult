namespace :supervisor do
  desc 'Execute Supervisor Rules...'
  task :run => :environment do
    queue_name = "supervisor_worker"
    if supervisor_should_run?(queue_name)
      Monitoring::RecordMetrics.register({:task_name => "Supervisor"})
      Sharding.execute_on_all_shards do
        Account.active_accounts.non_premium_accounts.each do |account| 
          if account.supervisor_rules.count > 0 
            Resque.enqueue(Workers::Supervisor, {:account_id => account.id })
          end
        end
      end
    end
  end

  task :premium => :environment do
    queue_name = "premium_supervisor_worker"
    if supervisor_should_run?(queue_name)
        Monitoring::RecordMetrics.register({:task_name => "Supervisor Premium"})
        Sharding.execute_on_all_shards do
          Account.active_accounts.premium_accounts.each do |account|
            if account.supervisor_rules.count > 0 
              Resque.enqueue(Workers::Supervisor::PremiumSupervisor, {:account_id => account.id })
            end
          end
        end
    end
  end
end

def supervisor_should_run?(queue_name)
  queue_length = Resque.redis.llen "queue:#{queue_name}"
  puts "#{queue_name} queue length is #{queue_length}"
  queue_length < 1 and !Rails.env.staging?
end