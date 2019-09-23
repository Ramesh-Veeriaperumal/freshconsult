class SubscriptionRequest < ActiveRecord::Base
  attr_accessible :account_id, :agent_limit, :fsm_field_agents, :plan_id, :renewal_period, :subscription_id
  
  self.primary_key = :id
  belongs_to_account
  belongs_to :subscription
  before_destroy :remove_scheduled_changes

  def remove_scheduled_changes
    account.subscription.billing.remove_scheduled_changes(account.id)
  end
  
  def plan_name
    subscription.subscription_plans_from_cache.find { |plan| plan.id == plan_id }.name
  end
end
