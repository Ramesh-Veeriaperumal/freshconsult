namespace :sla do
  desc 'Check for SLA violation and trigger emails..'
  task :escalate => :environment do
    queue_name = "sla_worker"
    if sla_should_run?(queue_name)
      puts "SLA violation check called at #{Time.zone.now}."
      Account.active_accounts.non_premium_accounts.each do |account|        
        Resque.enqueue(Workers::Sla::AccountSLA, { :account_id => account.id})
      end
    end
    puts "SLA rule check finished at #{Time.zone.now}."
  end

  task :premium => :environment do
    queue_name = "premium_sla_worker"
    if sla_should_run?(queue_name)
        puts "SLA violation check for Premium accounts called at #{Time.zone.now}."
        Account.active_accounts.premium_accounts.each do |account|
          Resque.enqueue(Workers::Sla::PremiumSLA, {:account_id => account.id})
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