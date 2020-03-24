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
          unless account.twitter_feature_present?
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
end
