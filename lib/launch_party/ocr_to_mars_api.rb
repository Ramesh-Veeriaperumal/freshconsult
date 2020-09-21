require 'launch_party/launch_party_feature'

class OcrToMarsApi < LaunchPartyFeature
  include Redis::OthersRedis
  include Redis::Keys::Others

  def on_launch(account_id)
    Sharding.select_shard_of(account_id) do
      account = Account.find(account_id).make_current
      add_member_to_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS, account.freshchat_account.app_id) if account.freshchat_account
      add_member_to_redis_set(OCR_TO_MARS_CALLER_ACCOUNT_IDS, account.freshcaller_account.freshcaller_account_id) if account.freshcaller_account
      Account.reset_current_account
    end
  end

  def on_rollback(account_id)
    Sharding.select_shard_of(account_id) do
      account = Account.find(account_id).make_current
      remove_member_from_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS, account.freshchat_account.app_id) if account.freshchat_account
      remove_member_from_redis_set(OCR_TO_MARS_CALLER_ACCOUNT_IDS, account.freshcaller_account.freshcaller_account_id) if account.freshcaller_account
      Account.reset_current_account
    end
  end
end
