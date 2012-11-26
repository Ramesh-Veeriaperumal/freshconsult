namespace :sla do
  desc 'Check for SLA violation and trigger emails..'
  task :escalate => :environment do
    puts "Check for SLA violation initialized at #{Time.zone.now}"
    queue_name = "SLA_worker"
    queue_length = Resque.redis.llen "queue:#{queue_name}"
    puts "current SLA que length is #{queue_length}"
    unless  queue_length > 0
      unless Rails.env.staging?
        puts "SLA violation check called at #{Time.zone.now}."
        Account.active_accounts.each do |account|
          Resque.enqueue(Workers::Sla, account.id)
        end
      end
    else
      puts "SLA Queue is already running . skipping at #{Time.zone.now}" 
    end
    puts "SLA rule check finished at #{Time.zone.now}."
  end
end