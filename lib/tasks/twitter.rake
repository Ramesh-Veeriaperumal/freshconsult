
namespace :twitter do
  desc 'Check for New twitter feeds..'
  task :fetch => :environment do    
    puts "Twitter task initialized at #{Time.zone.now}"
    queue_name = "TwitterWorker"
    queue_length = Resque.redis.llen "queue:#{queue_name}"
    puts "current twitter que length is #{queue_length}"
    unless   queue_length > 0
    	puts "Twitter Queue is empty... queuing at #{Time.zone.now}"
    	Account.active_accounts.each do |account|  
       		Resque.enqueue( Social::TwitterWorker ,{:account_id => account.id } )
    	end
    else
    	puts "Twitter Queue is already running . skipping at #{Time.zone.now}"  
    end
    puts "Twitter task closed at #{Time.zone.now}"
 end
 
end