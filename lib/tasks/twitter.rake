
namespace :twitter do
  desc 'Check for New twitter feeds..'
  task :fetch => :environment do    
    puts "Twitter task initialized at #{Time.zone.now}"
    queue_name = "TwitterWorker"
    queue_length = Resque.redis.llen "queue:#{queue_name}"
    puts "current twitter que length is #{queue_length}"
    unless   queue_length > 0
    	puts "Twitter Queue is empty... queuing at #{Time.zone.now}"
        Sharding.execute_on_all_shards do
    	   Account.active_accounts.each do |account|  
            next if account.twitter_handles.empty?  
       		Resque.enqueue( Social::TwitterWorker ,{:account_id => account.id } )
    	   end
        end
    else
    	puts "Twitter Queue is already running . skipping at #{Time.zone.now}"  
    end
    puts "Twitter task closed at #{Time.zone.now}"
 end
 
end