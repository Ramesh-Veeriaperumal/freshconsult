class AgentStatus < LaunchPartyFeature
  include Redis::OthersRedis
  include Redis::Keys::Others

  def on_launch(account_id)
    Sharding.select_shard_of(account_id) do
      account = Account.find(account_id).make_current
      add_member_to_redis_set(AGENT_STATUSES_CALLER_ACCOUNT_IDS, account.freshcaller_account.freshcaller_account_id) if account.freshcaller_account
      Account.reset_current_account
    end
  end

  def on_rollback(account_id)
    Sharding.select_shard_of(account_id) do
      account = Account.find(account_id).make_current
      remove_member_from_redis_set(AGENT_STATUSES_CALLER_ACCOUNT_IDS, account.freshcaller_account.freshcaller_account_id) if account.freshcaller_account
      Account.reset_current_account
    end
  end
end
