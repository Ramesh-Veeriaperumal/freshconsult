namespace :facebook do
  desc 'Check for New facebook feeds..'
  task :fetch => :environment do    
    puts "Facebook task initialized at #{Time.zone.now}"
    Account.active_accounts.each do |account|     
        Resque.enqueue( Social::FacebookWorker , account.id)              
     end   
    puts "Facebook task finished at #{Time.zone.now}"
  end

end