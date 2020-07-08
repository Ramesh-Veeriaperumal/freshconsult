module Fdadmin::SubscriptionControllerMethods

  def fetch_subscription_details(subscription_record)
    subscription_hash = {}
    subscription_hash[:account_id] = subscription_record.account_id
    subscription_hash[:state] = subscription_record.state
    subscription_hash[:amount] = subscription_record.amount
    subscription_hash[:next_renewal_at] = subscription_record.next_renewal_at
    subscription_hash[:created_at] = subscription_record.created_at
    subscription_hash[:currency_name] = subscription_record.currency_name
    subscription_hash[:account_name] = subscription_record.account.name
    subscription_hash
  end

  def search(search)
    results = []
    domain_mappings = DomainMapping.where(['domain LIKE ?', "%#{search}%"]).limit(30).select([:account_id,:domain])
    domain_mappings
  end

end
