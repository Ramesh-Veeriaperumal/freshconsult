namespace :custom_stream do 
  
  desc "Fetch custom twitter streams"
  task :twitter => :environment do
    queue_name = "twitter_stream_worker"
    if queue_empty?(queue_name)
      Sharding.run_on_all_shards do
        Account.current_pod.active_accounts.each do |account|
          next if account.twitter_handles.empty?
          Resque.enqueue(Social::Workers::Stream::Twitter, {:account_id => account.id})
        end
      end
    else
      puts "#{queue_name} is already running.skipping at #{Time.zone.now}"
    end
  end
  
  def queue_empty?(queue_name)
    queue_length = Resque.redis.llen "queue:#{queue_name}"
    puts "current #{queue_name} length is #{queue_length}"
    queue_length < 1
  end
  
end

