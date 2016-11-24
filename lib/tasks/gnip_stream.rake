namespace :gnip_stream do

  desc "Check if number of rules is same in gnip and helpkit"
  task :maintenance => :environment do
    include Social::Util
    db_set = Set.new #to be optimized
    Sharding.execute_on_all_shards do
      Social::TwitterStream.find_in_batches(:batch_size => 500,
        :joins => %(
          INNER JOIN `subscriptions` ON subscriptions.account_id = social_streams.account_id),
        :conditions => " subscriptions.state != 'suspended' "
      ) do |stream_block|
        stream_block.each do |stream|
          account = stream.account
          if !account.features?(:twitter)
            error_params = {
              :stream_id => stream.id,
              :account_id => stream.account_id,
              :data => stream.data
            }
            notify_social_dev("Twitter Streams present for non social plans", error_params)
          else
            if stream.data[:gnip] == true 
              unless stream.data[:rule_value].nil?
                db_set << {:rule_value => stream.data[:rule_value],
                            :rule_tag => stream.data[:rule_tag] }
              else
                error_params = {
                  :stream_id => stream.id,
                  :account_id => stream.account_id,
                  :rule_state => stream.data[:gnip_rule_state]
                }
                notify_social_dev("Default Stream rule value is NIL", error_params)
              end
            end
          end
        end
      end
    end
    Gnip::Constants::STREAM.each do |env_key, env_value|
      source = Gnip::Constants::SOURCE[:twitter]
      rules_url =  env_value.eql?("replay") ? GnipConfig::RULE_CLIENTS[source][:replay] : GnipConfig::RULE_CLIENTS[source][:production]
      result = Gnip::RuleClient.mismatch(db_set,rules_url,env_value)
    end
  end

  desc "Start listening to the replay stream"
  task :replay => :environment do
    disconnect_list = Social::Twitter::Constants::GNIP_DISCONNECT_LIST
    $redis_others.perform_redis_op("lrange", disconnect_list, 0, -1).each do |disconnected_period|
      period = JSON.parse(disconnected_period)
      if period[0] && period[1]
        end_time = DateTime.strptime(period[1], '%Y%m%d%H%M').to_time
        difference_in_seconds = (Time.now.utc - end_time).to_i
        if difference_in_seconds > Social::Twitter::Constants::TIME[:replay_stream_wait_time]
          args = {:start_time => period[0], :end_time => period[1]}
          puts "Gonna initialize ReplayStreamWorker #{Time.zone.now}"
          Social::Gnip::ReplayWorker.perform_async(args)
          $redis_others.perform_redis_op("lrem", disconnect_list, 1, disconnected_period)
        end
      end
    end
  end
  
  desc "Poll the sqs for pushing feeds to the respective stream"
  task :global_poll => :environment do
    include Social::Util
    queue = $sqs_twitter_global
    attributes = Rails.env.production? ? [] : [:sent_at]

    queue.poll(:initial_timeout => false,
               :batch_size => 10, :attributes => attributes) do |sqs_msg|
      tweet_stream = sqs_msg.body
      tweet_array = tweet_stream.split(Gnip::Constants::DELIMITER[:production_stream])
      tweet_array.each do |tweet|
        unless tweet.blank?
          gnip_msg = Social::Gnip::TwitterFeed.new(tweet, queue)
          next if gnip_msg.blank?
          gnip_msg.tag_objs.each do |tag_obj|
            tweet = gnip_msg.tweet_obj
            pod   = determine_pod(tag_obj, tweet)
            
            # send message to the specific queue
            Rails.logger.info "Tweet received for POD: #{pod}."
           
            if pod
              $sqs_twitter.send_message(tweet.to_json) 
            elsif !$sqs_twitter_euc.nil?
              $sqs_twitter_euc.send_message(tweet.to_json) 
            else
              notify_social_dev("Message not sent to both pods", {:tweet => tweet})
           end
          end
        end
      end
    end
  end
  
  def determine_pod(tag_obj, tweet)
    stream_id     = tag_obj.stream_id
    account_id    = tag_obj.account_id
    shard_mapping = ShardMapping.find_by_account_id(account_id)
    if shard_mapping && shard_mapping.ok?
      tweet[:gnip]["matching_rules"] = [{
        "value" => "", # Since not using rule value to check, sending as empty space
        "tag"   => "#{stream_id}_#{account_id}" 
      }]
      shard_mapping.pod_info
    end
  end

  desc "Poll the sqs for converting tweets to tickets"
  task :poll => :environment do
    #Should be the pod specific queue
    queue = $sqs_twitter
    attributes = Rails.env.production? ? [] : [:sent_at]

    queue.poll(:initial_timeout => false,
               :batch_size => 10, :attributes => attributes) do |sqs_msg|
      process_tweet sqs_msg, queue
    end
  end

  task :poll_v2 => :environment do
    #Should be the pod specific queue
    queue = $sqs_gnip_2_0
    attributes = Rails.env.production? ? [] : [:sent_at]

    queue.poll(:initial_timeout => false,
               :batch_size => 10, :attributes => attributes) do |sqs_msg|
      process_tweet sqs_msg, queue
    end
  end

  def process_tweet sqs_msg, queue
    tweet = sqs_msg.body
    unless tweet.blank?
      gnip_msg = Social::Gnip::TwitterFeed.new(tweet, queue)
      unless gnip_msg.nil?
        begin
          gnip_msg.process
        rescue Exception => e
          Rails.logger.debug "Exception in processing tweet"
          Rails.logger.debug tweet.inspect
          NewRelic::Agent.notice_error(e, 
            { :custom_params => { :description => "JSON Parse error in gnip feed",
                                  :tweet_obj => tweet }})
        end
        log_timeline(gnip_msg, sqs_msg.sent_at) unless Rails.env.production?
      end
    end
  end

  def log_timeline(tweet, sent_at)
    return unless tweet.posted_time && tweet.tweet_id
    posted_time = Time.parse(tweet.posted_time)
    tweet_id = tweet.tweet_id
    enqueued_at = sent_at - posted_time
    converted_at = Time.zone.now.utc - sent_at
    puts "Tweet ID :: #{tweet_id} - posted at #{posted_time.to_s} enqueued in #{enqueued_at} sec." \
          " Converted to ticket/note in #{converted_at} sec"
  end
end
