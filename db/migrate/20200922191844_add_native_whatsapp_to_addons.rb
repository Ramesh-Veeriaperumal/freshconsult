# frozen_string_literal: true

class AddNativeWhatsappToAddons < ActiveRecord::Migration
  shard :none
  def up
    addon_types = Subscription::Addon::ADDON_TYPES
    sub_plans = ['Garden Jan 17', 'Estate Jan 17', 'Forest Jan 17',
                 'Garden Jan 19', 'Estate Jan 19', 'Garden Omni Jan 19', 'Estate Omni Jan 19', 'Forest Jan 19',
                 'Garden Jan 20', 'Estate Jan 20', 'Forest Jan 20', 'Estate Omni Jan 20', 'Forest Omni Jan 20'].freeze
    Subscription::Addon.create(name: 'Native Whatsapp', amount: 49.0, renewal_period: 1, addon_type: addon_types[:for_account].to_s)
    sub_plans.each do |sub_plan_name|
      sub_plan_id = SubscriptionPlan.where(name: sub_plan_name).first.id
      sub_addon_id = Subscription::Addon.where(name: 'Native Whatsapp').first.id
      Subscription::PlanAddon.create(subscription_addon_id: sub_addon_id, subscription_plan_id: sub_plan_id)
    end
  end

  def down
    sub_addon_id = Subscription::Addon.where(name: 'Native Whatsapp').first.id
    sub_plan_addons = Subscription::PlanAddon.where(subscription_addon_id: sub_addon_id)
    sub_plan_addons.destroy_all
    whatsapp_addon = Subscription::Addon.where(name: 'Native Whatsapp')
    whatsapp_addon.destroy_all
  end
end
