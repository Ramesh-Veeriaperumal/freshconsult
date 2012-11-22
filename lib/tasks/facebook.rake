namespace :facebook do
  desc 'Check for New facebook feeds..'
  task :fetch => :environment do    
    puts "Facebook task initialized at #{Time.zone.now}"
    queue_name = "FacebookWorker"
    queue_length = Resque.redis.llen "queue:#{queue_name}"
    puts "current Facebook que length is #{queue_length}"
    unless   queue_length > 0
    	puts "Facebook Queue is empty... queuing at #{Time.zone.now}"
    	Account.active_accounts.each do |account| 
    	    next if account.facebook_pages.empty?    
        	Resque.enqueue( Social::FacebookWorker , account.id)              
     	end 
    else
      puts "Facebook Queue is already running . skipping at #{Time.zone.now}"  
    end
    puts "Facebook task finished at #{Time.zone.now}"
  end

end