module Fdadmin::SubscriptionControllerMethods

  def fetch_subscription_details(account_records)
    subscription_array = []
    account_records.each do |subscription|
      subscription_hash = {}
      subscription_hash[:account_id] = subscription.account_id
      subscription_hash[:state] = subscription.state
      subscription_hash[:amount] = subscription.amount
      subscription_hash[:next_renewal_at] = subscription.next_renewal_at
      subscription_hash[:created_at] = subscription.created_at
      subscription_hash[:currency_name] = subscription.currency_name
      subscription_hash[:account_name] = subscription.account.name
      subscription_array << subscription_hash
    end
    subscription_array
  end

  def search(search)
    results = []
    domain_mappings = DomainMapping.find(:all,
                                         :conditions => ['domain LIKE ? and portal_id IS ?', "%#{search}%", nil], :limit => 30)

    unless search.blank?
      domain_mappings.each do |domain|
        Sharding.admin_select_shard_of(domain.account_id) do
          Sharding.run_on_slave do
            results << Subscription.find_by_account_id(domain.account_id, :include => :account)
          end
        end
      end
    end
    results
  end

end
