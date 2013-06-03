namespace :sla do
  desc 'Check for SLA violation and trigger emails..'
  task :escalate => :environment do
    puts "Check for SLA violation initialized at #{Time.zone.now}"
    queue_name = "sla_worker"
    if sla_should_run?(queue_name)
      puts "SLA violation check called at #{Time.zone.now}."
      Sharding.execute_on_all_shards do
        Account.active_accounts.each do |account|        
          Resque.enqueue(Workers::Sla::AccountSLA, { :account_id => account.id})
        end
      end
    end
    puts "SLA rule check finished at #{Time.zone.now}."
  end

 
end

def sla_should_run?(queue_name)
  queue_length = Resque.redis.llen "queue:#{queue_name}"
  puts "#{queue_name} queue length is #{queue_length}"
  queue_length < 1 and !Rails.env.staging?
end