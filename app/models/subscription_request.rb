class SubscriptionRequest < ActiveRecord::Base
  include SubscriptionHelper
  include Redis::OthersRedis
  attr_accessible :account_id, :agent_limit, :fsm_field_agents, :plan_id, :renewal_period, :subscription_id
  attr_accessor :next_renewal_at

  self.primary_key = :id
  belongs_to_account
  belongs_to :subscription
  belongs_to :subscription_plan, foreign_key: 'plan_id'
  after_commit -> { trigger_downgrade_policy_reminder_scheduler(next_renewal_at) }, on: :create
  after_commit :reset_downgrade_policy_key, on: :destroy
  before_destroy :remove_scheduled_changes

  def reset_downgrade_policy_key
    remove_others_redis_key(account.downgrade_policy_email_reminder_key) if redis_key_exists?(account.downgrade_policy_email_reminder_key)
  end

  def remove_scheduled_changes
    subscription.billing.remove_scheduled_changes(account_id)
  end

  def plan_name
    subscription.subscription_plans_from_cache.find { |plan| plan.id == plan_id }.name
  end
end
