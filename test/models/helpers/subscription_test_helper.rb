module SubscriptionTestHelper

  def update_subscription
    subscription = Account.current.subscription
    subscription.card_number = Faker::Number.number(10)
    subscription.save
  end

  def central_publish_post_pattern(subscription)
    {
      id: subscription.id,
      amount: subscription.amount.to_i,
      card_number: subscription.card_number,
      card_expiration: subscription.card_expiration,
      state: subscription.state,
      subscription_plan_id: subscription.subscription_plan_id,
      account_id: subscription.account_id,
      renewal_period: subscription.renewal_period,
      billing_id: subscription.billing_id,
      subscription_discount_id: subscription.subscription_discount_id,
      subscription_affiliate_id: subscription.subscription_affiliate_id,
      agent_limit: subscription.agent_limit,
      free_agents: subscription.free_agents,
      day_pass_amount: subscription.day_pass_amount.to_i,
      subscription_currency_id: subscription.subscription_currency_id,
      created_at: subscription.created_at.try(:utc).try(:iso8601),
      updated_at: subscription.updated_at.try(:utc).try(:iso8601),
      next_renewal_at: subscription.next_renewal_at.try(:utc).try(:iso8601),
      discount_expires_at: subscription.discount_expires_at.try(:utc).try(:iso8601),
      account_plan: subscription.subscription_plan.display_name
    }
  end
end
