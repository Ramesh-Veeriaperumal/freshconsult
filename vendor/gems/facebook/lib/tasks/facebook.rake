namespace :facebook do

  desc "Poll the sqs for processing facebook objects"
  task :realtime => :environment do
    include Facebook::RedisMethods
    include Facebook::Exception::Notifier

    $sqs_facebook.poll(:initial_timeout => false, :batch_size => 10) do |sqs_msg|
      begin
        #Check for app rate limit before processing feeds
        wait_on_poll if app_rate_limit_reached?

        puts "FEED ===> #{sqs_msg.body}"

        Sqs::Message.new(sqs_msg.body).process
      rescue => e
        NewRelic::Agent.notice_error(e, {:description => "Error while processing sqs request"})
      end
    end
  end

  desc "Collect Facebook Likes stored in redis and push it to Dynamo in a 30 minute interval"
  task :push_likes => :environment do
    include Social::Util
    include Facebook::RedisMethods
    
    begin
      Rails.logger.info "START TIME :: #{Time.now.utc}"
      process_likes_from_redis
      Rails.logger.info "END TIME :: #{Time.now.utc}"
    rescue => e
      notify_social_dev("Error while processing likes", e.backtrace)
    end
  end


  def wait_on_poll
    subject = "APP RATE LIMIT - REACHED SKIPPING PROCESS"
    message = {:time_at => Time.now.utc, :sleep_for => APP_RATE_LIMIT_EXPIRY}
    raise_sns_notification(subject, message)
    Rails.logger.error "Sleeping the process due to APP RATE LIMT"
    sleep(APP_RATE_LIMIT_EXPIRY)
  end

end
