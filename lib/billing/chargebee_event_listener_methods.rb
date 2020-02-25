module Billing::ChargebeeEventListenerMethods
  include Redis::OthersRedis
  include Redis::RedisKeys
  include Billing::BillingHelper

  def subscription_renewed(event_data, account)
    content = event_data.content
    addons = content.subscription.addons && content.subscription.addons.map(&:to_h)
    if throttle_subscription_renewal?(content.subscription.plan_quantity,
                                      content.subscription.plan_id, addons, account)
      raise 'Differences in subscription renewal invoice amount, retry.'
    end

    account.launch(:downgrade_policy)
    card_expiry_key = format(CARD_EXPIRY_KEY, account_id: account.id)
    subscription_data = construct_subscription_data(content)
    account.subscription.update_attributes(subscription_data)
    set_others_redis_hash(card_expiry_key, next_renewal: subscription_data[:next_renewal_at]) if redis_key_exists?(card_expiry_key)
  end
end
