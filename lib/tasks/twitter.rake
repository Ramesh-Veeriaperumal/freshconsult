
namespace :twitter do
  desc 'Check for New twitter feeds..'
  task :fetch => :environment do    
    puts "Twitter task initialized at #{Time.zone.now}"
    Account.active_accounts.each do |account|    
       Resque.enqueue( Social::TwitterWorker , account.id)   
    end
    puts "Twitter task closed at #{Time.zone.now}"
 end
 
end