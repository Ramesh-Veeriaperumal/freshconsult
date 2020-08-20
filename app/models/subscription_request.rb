class SubscriptionRequest < ActiveRecord::Base
  include SubscriptionHelper
  include Redis::OthersRedis
  attr_accessible :account_id, :agent_limit, :fsm_field_agents, :plan_id, :renewal_period, :subscription_id, :feature_loss
  attr_accessor :next_renewal_at, :from_plan, :fsm_downgrade

  self.primary_key = :id
  belongs_to_account
  belongs_to :subscription
  belongs_to :subscription_plan, foreign_key: 'plan_id'
  after_commit -> { trigger_downgrade_policy_reminder_scheduler(next_renewal_at) }, on: :create
  after_commit :reset_downgrade_policy_key, on: :destroy
  before_destroy :remove_scheduled_changes
  before_save :set_feature_loss

  def reset_downgrade_policy_key
    remove_others_redis_key(account.downgrade_policy_email_reminder_key) if redis_key_exists?(account.downgrade_policy_email_reminder_key)
  end

  def remove_scheduled_changes
    subscription.billing.remove_scheduled_changes(account_id)
  end

  def plan_name
    subscription.subscription_plans_from_cache.find { |plan| plan.id == plan_id }.name
  end

  def fsm_enabled?
    fsm_field_agents.present?
  end

  def product_loss?
    account.has_feature?(:unlimited_multi_product) && !subscription_plan.unlimited_multi_product? &&
      subscription_plan.multi_product? && account.products.count > AccountConstants::MULTI_PRODUCT_LIMIT
  end

  private

  def set_feature_loss
    return if from_plan.nil?

    if from_plan.id == plan_id
      self.feature_loss = omni_plan_downgrade? || fsm_downgrade
    else
      plan_features = PLANS[:subscription_plans].collect{ |plan_name, plan| plan[:features].dup }.flatten.uniq.freeze
      self.feature_loss = ((account.features_list & plan_features) -
        PLANS[:subscription_plans][subscription_plan.canon_name][:features]).present? || omni_plan_downgrade? || fsm_downgrade
    end
    true
  end

  def omni_plan_downgrade?
    from_plan.omni_plan? && subscription_plan.basic_variant?
  end
end
