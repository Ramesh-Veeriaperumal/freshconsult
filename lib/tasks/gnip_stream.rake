
namespace :gnip_stream do

  desc "Add existing twitter_handles to gnip rules"
  task :bootstrap => :environment do
    Sharding.execute_on_all_shards do
      Account.active_accounts.each do |account|
        next if account.twitter_handles.empty?
        account.twitter_handles.each do |handle|
          if handle.capture_mention_as_ticket &&
                handle.gnip_rule_state == Social::TwitterHandle::GNIP_RULE_STATES_KEYS_BY_TOKEN[:none]
            handle.subscribe_to_gnip
          end
        end
      end
    end
  end

  desc "Check if no of rules is same in gnip and helpkit"
  task :maintenance => :environment do
    db_array = Array.new
    Sharding.execute_on_all_shards do
      Account.active_accounts.each do |account|
        next if account.twitter_handles.empty?
        twitter_handles = account.twitter_handles.active
        twitter_handles.each do |twt_handle|
          if twt_handle.capture_mention_as_ticket
            unless twt_handle.rule_value.nil?
              db_array << {:rule_value => twt_handle.rule_value, 
                         :rule_tag => twt_handle.rule_tag}
            else
              NewRelic::Agent.notice_error("Handle's rule value is NULL", 
                            :custom_params => {:twitter_handle_id => twt_handle.id })
            end 
          end
        end
      end
    end
    Social::Gnip::Constants::STREAM.each do |env_key, env_value|
      rules_url =  env_value.eql?("replay") ? GnipConfig::REPLAY_RULES_URL : GnipConfig::PRODUCTION_RULES_URL
      result = Social::Gnip::Rule.mismatch(db_array,rules_url,env_value)
    end
  end

end
