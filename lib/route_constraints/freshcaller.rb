module RouteConstraints
  class Freshcaller
    def matches?(request)
      account_id = ShardMapping.lookup_with_domain(request.host).try(:account_id).to_i
      Sharding.select_shard_of(account_id) do
        account = Account.find_by_id(account_id).make_current
        account.present? && account.freshcaller_enabled?
      end
    end
  end
end
