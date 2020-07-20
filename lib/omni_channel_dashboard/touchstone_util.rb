# frozen_string_literal: true

module OmniChannelDashboard::TouchstoneUtil
  def omni_bundle_enabled?
    current_account = Account.current
    current_account.try(:invoke_touchstone_enabled?) && current_account.try(:omni_bundle_account?) && SubscriptionPlan.omni_channel_plan.map(&:id).include?(current_account.try(:subscription).try(:subscription_plan).try(:id))
  end

  def invoke_touchstone_account_worker
    OmniChannelDashboard::AccountWorker.perform_async(action: 'update')
  end
end
