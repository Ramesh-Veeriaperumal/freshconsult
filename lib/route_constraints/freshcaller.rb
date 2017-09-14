module RouteConstraints
  class Freshcaller
    def matches?(request)
      account_id = ShardMapping.lookup_with_domain(request.host).try(:account_id).to_i
      Sharding.select_shard_of(account_id) do
        Sharding.run_on_slave do
          account = Account.find_by_id(account_id).make_current
          account.present? && account.has_feature?(:freshcaller)
        end
      end
    end
  end
end
