
namespace :twitter do
  desc 'Check for New twitter feeds..'
  
 PREMIUM_ACC_IDS = {:staging => [390], :production => [18685]}

  task :fetch => :environment do    
    queue_name = "TwitterWorker"
    if queue_empty?(queue_name)
        puts "Twitter Queue is empty... queuing at #{Time.zone.now}"
        Sharding.execute_on_all_shards do
    	   Account.active_accounts.each do |account|  
            next if check_if_premium?(account) || account.twitter_handles.empty?  
       		Resque.enqueue( Social::TwitterWorker ,{:account_id => account.id } )
    	   end
        end
    else
    	puts "Twitter Queue is already running . skipping at #{Time.zone.now}"  
    end
    puts "Twitter task closed at #{Time.zone.now}"
 end

  task :premium => :environment do
    queue_name = "premium_twitter_worker"
    premium_acc_ids = Rails.env.production? ? PREMIUM_ACC_IDS[:production] : PREMIUM_ACC_IDS[:staging]
    if queue_empty?(queue_name)
      premium_acc_ids.each do |account_id|
        Resque.enqueue(Social::TwitterWorker::PremiumTwitterWorker, {:account_id => account_id })
      end
    else
      puts "Premium Twitter Worker is already running . skipping at #{Time.zone.now}" 
    end
  end

 def queue_empty?(queue_name)
    queue_length = Resque.redis.llen "queue:#{queue_name}"
    puts "current #{queue_name} length is #{queue_length}"
    queue_length < 1
end

 def check_if_premium?(account)
    Rails.env.production? ? PREMIUM_ACC_IDS[:production].include?(account.id) : 
                            PREMIUM_ACC_IDS[:staging].include?(account.id)
 end
 
end