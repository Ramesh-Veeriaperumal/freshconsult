namespace :supervisor do
  desc 'Execute Supervisor Rules...'
  task :run => :environment do
    puts "Supervisor rule check started at #{Time.zone.now}"
    unless Rails.env.staging?
      queue_length = Resque.redis.llen "queue:supervisor_worker"
      unless  queue_length > 0
        Account.active_accounts.each do |account|
          if account.supervisor_rules.count > 0
            Resque.enqueue( Workers::Supervisor, account.id)
          end
        end
      else
        puts "Supervisor Queue is already running . skipping at #{Time.zone.now}" 
      end
    else
      puts "Skiping supervisor rule check as its a staging environment - at #{Time.zone.now}" 
    end
    puts "Supervisor rule check finished at #{Time.zone.now}."    
  end
end