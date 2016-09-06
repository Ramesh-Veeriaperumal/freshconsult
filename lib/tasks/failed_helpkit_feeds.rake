namespace :failed_helpkit_feeds do

	# This cron runs every five mins
  # Has the following command
  # "*/10  *   *   *   *"  bundle exec rake failed_helpkit_feeds:retry

	task :requeue => :environment do
		include Redis::RedisKeys
		include Redis::OthersRedis
		begin
			return if redis_key_exists?(PROCESSING_FAILED_HELPKIT_FEEDS)
			if set_others_redis_key(PROCESSING_FAILED_HELPKIT_FEEDS, "1")
				FailedHelpkitFeed.find_each do |feed|
					feed.requeue
		    	feed.destroy
				end
			end
		rescue => e
			message = "#{e.inspect}\n#{e.backtrace.join("\n")}"
			puts message
			DevNotification.publish(SNS["freshdesk_team_notification_topic"], "Exception in requeue of failed helpkit feeds", message)
			NewRelic::Agent.notice_error(e)										 
		ensure
			remove_others_redis_key PROCESSING_FAILED_HELPKIT_FEEDS
		end
	end
end
    
