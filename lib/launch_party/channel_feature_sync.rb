# frozen_string_literal: true

require 'launch_party/launch_party_feature'

class ChannelFeatureSync < LaunchPartyFeature
  include Redis::RedisKeys
  include Redis::OthersRedis

  def on_launch(account_id)
    Sharding.select_shard_of(account_id) do
      Account.find(account_id).make_current
      args = construct_params(account_id)
      ChannelFeatureSyncWorker.perform_in(delay_time_for_channel(ApiBusinessCalendarConstants::FRESHCHAT_PRODUCT.upcase).seconds.from_now,
                                          args.merge(channel: :freshchat))
      ChannelFeatureSyncWorker.perform_in(delay_time_for_channel(ApiBusinessCalendarConstants::FRESHCALLER_PRODUCT.upcase).seconds.from_now,
                                          args.merge(channel: :freshcaller))
      Account.reset_current_account
    end
  end

  def on_rollback(account_id)
    Sharding.select_shard_of(account_id) do
      Account.find(account_id).make_current
      args = construct_params(account_id, false)
      ChannelFeatureSyncWorker.perform_in(delay_time_for_channel(ApiBusinessCalendarConstants::FRESHCHAT_PRODUCT.upcase).seconds.from_now,
                                          args.merge(channel: :freshchat))
      ChannelFeatureSyncWorker.perform_in(delay_time_for_channel(ApiBusinessCalendarConstants::FRESHCALLER_PRODUCT.upcase).seconds.from_now,
                                          args.merge(channel: :freshcaller))
      Account.reset_current_account
    end
  end

  private

    def construct_params(account_id, launch = true)
      params = {
        account_id: account_id,
        resource_type: :feature_toggle,
        action: :update,
        enable_feature: launch
      }
      params[:params] = {
        "#{launch ? :enable : :disable}_features": [feature_name]
      }
      params
    end

    def delay_time_for_channel(channel_name)
      (get_others_redis_key(Object.const_get("OMNI_CHANNEL_#{channel_name}_API_DELAY_TIME")) || 60).to_i
    end
end
