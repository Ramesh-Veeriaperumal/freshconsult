namespace :gnip_stream do

  desc "Check if number of rules is same in gnip and helpkit"
  task :maintenance => :environment do
    db_set = Set.new #to be optimized
    Sharding.execute_on_all_shards do
      Social::TwitterHandle.find_in_batches(:batch_size => 500,
        :joins => %(
          INNER JOIN `subscriptions` ON subscriptions.account_id = social_twitter_handles.account_id),
        :conditions => " subscriptions.state != 'suspended' "
      ) do |twitter_block|
        twitter_block.each do |twt_handle|
          if twt_handle.capture_mention_as_ticket
            unless twt_handle.rule_value.nil?
              db_set << {:rule_value => twt_handle.rule_value,
                           :rule_tag => twt_handle.rule_tag}
            else
              NewRelic::Agent.notice_error("Handle's rule value is NULL", :custom_params => {
                :twitter_handle_id => twt_handle.id, :account_id => twt_handle.account_id})
            end
          end
        end
      end
      Social::TwitterStream.find_in_batches(:batch_size => 500,
        :joins => %(
          INNER JOIN `subscriptions` ON subscriptions.account_id = social_streams.account_id),
        :conditions => " subscriptions.state != 'suspended' "
      ) do |stream_block|
        stream_block.each do |stream|
          unless stream.data[:rule_value].nil?
            db_set << {:rule_value => stream.data[:rule_value],
                        :rule_tag => stream.data[:rule_tag] }
          else
             NewRelic::Agent.notice_error("Stream's rule value is NULL", :custom_params => {
                :stream_id => stream.id, :account_id => stream.account_id})
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
    $redis_others.lrange(disconnect_list, 0, -1).each do |disconnected_period|
      period = JSON.parse(disconnected_period)
      if period[0] && period[1]
        end_time = DateTime.strptime(period[1], '%Y%m%d%H%M').to_time
        difference_in_seconds = (Time.now.utc - end_time).to_i
        if difference_in_seconds > Social::Twitter::Constants::TIME[:replay_stream_wait_time]
          args = {:start_time => period[0], :end_time => period[1]}
          puts "Gonna initialize ReplayStreamWorker #{Time.zone.now}"
          Resque.enqueue(Social::Twitter::Workers::Replay, args)
          $redis_others.lrem(disconnect_list, 1, disconnected_period)
        end
      end
    end
  end

  desc "Poll the sqs for converting tweets to tickets"
  task :poll => :environment do
    queue = $sqs_twitter
    attributes = Rails.env.production? ? [] : [:sent_at]

    queue.poll(:initial_timeout => false,
               :batch_size => 10, :attributes => attributes) do |sqs_msg|
      tweet_stream = sqs_msg.body
      tweet_array = tweet_stream.split(Gnip::Constants::DELIMITER[:production_stream])
      tweet_array.each do |tweet|
        unless tweet.blank?
          gnip_msg = Social::Twitter::Feed.new(tweet, queue)
          unless gnip_msg.nil?
            gnip_msg.process
            log_timeline(gnip_msg, sqs_msg.sent_at) unless Rails.env.production?
          end
        end
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
