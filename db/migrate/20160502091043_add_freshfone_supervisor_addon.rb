class AddFreshfoneSupervisorAddon < ActiveRecord::Migration
  shard :none

  ADDON_NAME = 'Call Center Advanced'

  def self.up
    addon_types = Subscription::Addon::ADDON_TYPES
    Subscription::Addon.create(
      name: ADDON_NAME,
      amount: 24.0,
      renewal_period: 1,
      addon_type: addon_types[:agent_quantity])

    Subscription::PlanAddon.create(supervisor_addon_params)
  end

  def self.down
    Subscription::PlanAddon.where(subscription_addon_id: supervisor_subscription_addon_id).delete_all
    Subscription::Addon.where(name: ADDON_NAME).delete_all
  end

  def supervisor_subscription_addon_id
    Subscription::Addon.find_by_name(ADDON_NAME).id
  end

  def supervisor_addon_params
    SubscriptionPlan.all.map do |plan|
      [{subscription_plan_id: plan.id, subscription_addon_id: supervisor_subscription_addon_id}]
    end
  end
end