module Social::Gnip::DbUtil

  def self.included(base)
    base.extend ClassMethods
    base.send(:include, ClassMethods)
  end

  module ClassMethods

    include Social::Twitter::Constants
    include Gnip::Constants
    include Social::Constants
    include Social::Util
    include Social::Gnip::Util

    def update_db(env, action, params)
      @replay = env.eql?(STREAM[:replay])
      tag_array = params[:rule_tag].split(DELIMITER[:tags])
      tag_array.each do |gnip_tag|
        tag = Gnip::RuleTag.new(gnip_tag)
        next unless tag.stream_id.starts_with?(TAG_PREFIX) #discard twitter_handle tweets
        args = {
          :account_id => tag.account_id,
          :stream_id  => tag.stream_id
        }
        params.merge!(args)
        update_social_streams(action, params)
      end
    end

    private

    def update_social_streams(action, args)
      select_shard_and_account(args[:account_id]) do |account|
        stream = account.twitter_streams.find_by_id(args[:stream_id].gsub(TAG_PREFIX,  ""))
        if stream && args[:response]
          rule_state = gnip_rule_state(action, stream)
          attributes = {
            :gnip_rule_state => rule_state.nil? ? stream.data[:gnip_rule_state] : rule_state
          }
          unless @replay
            attributes.merge!(
              :rule_tag   => action.eql?(RULE_ACTION[:add]) ? args[:rule_tag] : nil,
              :rule_value => action.eql?(RULE_ACTION[:add]) ? args[:rule_value] : nil
            )
          end
          stream.data.update(attributes)
          stream.save
        end
      end
    end

    def gnip_rule_state(action, item)
      power_track_env = @replay ? GNIP_RULE_STATES_KEYS_BY_TOKEN[:replay] : GNIP_RULE_STATES_KEYS_BY_TOKEN[:production]
      current_state = item.is_a?(Social::Stream) ? item.data[:gnip_rule_state] : item.gnip_rule_state
      if action == RULE_ACTION[:add]
        rule_state = current_state | power_track_env
      elsif action == RULE_ACTION[:delete]
        rule_state = current_state - power_track_env if (current_state & power_track_env) > 0
      end
      return rule_state
    end
  end
end
