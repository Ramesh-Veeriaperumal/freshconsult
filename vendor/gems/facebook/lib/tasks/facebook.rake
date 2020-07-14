namespace :facebook do

  desc "Poll the sqs for processing facebook objects"
  task :realtime => :environment do
    include Facebook::RedisMethods
    include Facebook::Exception::Notifier

    AwsWrapper::SqsV2.poll(SQS[:facebook_realtime_queue]) do |sqs_msg|
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

  desc "poll the sqs for processing real time facebook message"
  task :realtime_fb_message => :environment do
    include Facebook::RedisMethods
    include Facebook::Exception::Notifier
    include Facebook::CentralMessageUtil

    AwsWrapper::SqsV2.poll(SQS[:fb_message_realtime_queue]) do |sqs_msg|
      begin
        #Check for app rate limit before processing feeds
        wait_on_poll if app_rate_limit_reached?

        type = CENTRAL_PAYLOAD_TYPES[:message]
        message = get_message(sqs_msg.body, type)

        if message.present?
          puts "Facebook Message ===> #{message}"
          facebook_message = Sqs::FacebookMessage.new(message)
          facebook_message.process
        else
          Rails.logger.debug "Message intended for another POD."
        end
      rescue => e
        NewRelic::Agent.notice_error(e, {:description => "Error while processing sqs request"})
        Rails.logger.error "Error while processing sqs request, error: #{e.message}"
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
      Rails.logger.error "Error while processing likes :: Exception: #{e.message} :: #{e.backtrace[0..20]}"
    end
  end

  # PRE-RAILS: sqs_facebook_global is not present anywhere, need to check and remove it.
  # task :global_realtime => :environment do
  #   $sqs_facebook_global.poll("Facebook::Core::Splitter", "split", batch_size: 10, initial_timeout: false) 
  # end

  def wait_on_poll
    subject = "APP RATE LIMIT - REACHED SKIPPING PROCESS"
    message = {:time_at => Time.now.utc, :sleep_for => APP_RATE_LIMIT_EXPIRY}
    Rails.logger.error "Sleeping the process due to APP RATE LIMT"
    notify_fb_mailer(nil, message, subject)
    sleep(APP_RATE_LIMIT_EXPIRY)
    wait_on_poll if app_rate_limit_reached?
  end

end
