class AddFreddyAdditionalSessionsPackToAddons < ActiveRecord::Migration
  shard :all
  def up
    addon_types = Subscription::Addon::ADDON_TYPES
    freddy_session_packs_addons = SubscriptionConstants::FREDDY_SESSION_PACK_ADDONS
    sub_plans = ['Blossom Jan 17', 'Garden Jan 17', 'Estate Jan 17', 'Forest Jan 17',
                 'Blossom Jan 19', 'Garden Jan 19', 'Estate Jan 19', 'Garden Omni Jan 19', 'Estate Omni Jan 19', 'Forest Jan 19',
                 'Blossom Jan 20', 'Garden Jan 20', 'Estate Jan 20', 'Forest Jan 20', 'Estate Omni Jan 20', 'Forest Omni Jan 20'].freeze
    Subscription::Addon.create(name: Subscription::Addon::FREDDY_MONTHLY_SESSION_PACKS_ADDON, amount: 100.0, renewal_period: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:monthly], addon_type: addon_types[:session_packs])
    Subscription::Addon.create(name: Subscription::Addon::FREDDY_QUARTERLY_SESSION_PACKS_ADDON, amount: 100.0, renewal_period: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:quarterly], addon_type: addon_types[:session_packs])
    Subscription::Addon.create(name: Subscription::Addon::FREDDY_HALF_YEARLY_SESSION_PACKS_ADDON, amount: 100.0, renewal_period: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:six_month], addon_type: addon_types[:session_packs])
    Subscription::Addon.create(name: Subscription::Addon::FREDDY_ANNUAL_SESSION_PACKS_ADDON, amount: 100.0, renewal_period: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual], addon_type: addon_types[:session_packs])
    sub_plans.each do |sub_plan_name|
      sub_plan_id = SubscriptionPlan.where(name: sub_plan_name).first.id
      freddy_session_packs_addons.each do |session_pack_addon|
        sub_addon_id = Subscription::Addon.where(name: session_pack_addon).first.id
        Subscription::PlanAddon.create(subscription_addon_id: sub_addon_id, subscription_plan_id: sub_plan_id)
      end
    end
  end

  def down
    freddy_session_packs_addons = SubscriptionConstants::FREDDY_SESSION_PACK_ADDONS
    freddy_session_packs_addons.each do |session_pack_addon|
      sub_addon_id = Subscription::Addon.where(name: session_pack_addon).first.id
      sub_plan_addons = Subscription::PlanAddon.where(subscription_addon_id: sub_addon_id)
      sub_plan_addons.destroy_all
    end
    session_packs_addons = Subscription::Addon.where(name: freddy_session_packs_addons)
    session_packs_addons.destroy_all
  end
end
