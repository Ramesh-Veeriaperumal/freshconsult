class SubscriptionRequest < ActiveRecord::Base
  attr_accessible :account_id, :agent_limit, :fsm_feature_enabled, :plan_id, :renewal_period, :subscription_id

  self.primary_key = :id
  belongs_to_account
  belongs_to :subscription
end
