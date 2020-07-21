# frozen_string_literal: true

require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class AccountAdditionalSettingsTest < ActiveSupport::TestCase
  include AccountTestHelper

  def setup
    super
    @account = create_test_account if @account.nil?
    @account.make_current
  end

  def test_update_bundle_id_invoke_account_worker
    OmniChannelDashboard::AccountWorker.jobs.clear
    @account.rollback(:omni_channel_dashboard)
    @account.launch(:omni_bundle_2020)
    @account.launch(:invoke_touchstone)
    old_subscription_id = @account.try(:subscription).try(:subscription_plan).try(:id)
    @account.subscription.subscription_plan.id = SubscriptionPlan.omni_channel_plan.map(&:id).first
    additional_settings = AccountAdditionalSettings.last
    @account.account_additional_settings = additional_settings
    @account.save
    @account.account_additional_settings.additional_settings[:bundle_id] = 1
    @account.account_additional_settings.save!
    assert_equal 1, OmniChannelDashboard::AccountWorker.jobs.size
    assert_equal 'create', OmniChannelDashboard::AccountWorker.jobs.last['args'][0]['action']
    @account.reload
    @account.subscription.subscription_plan.id = SubscriptionPlan.omni_channel_plan.map(&:id).first
    @account.account_additional_settings.additional_settings[:bundle_id] = 3
    @account.account_additional_settings.save!
    assert_equal 2, OmniChannelDashboard::AccountWorker.jobs.size
    assert_equal 'update', OmniChannelDashboard::AccountWorker.jobs.last['args'][0]['action']
  ensure
    @account.subscription.subscription_plan.id = old_subscription_id
    OmniChannelDashboard::AccountWorker.jobs.clear
    @account.rollback(:omni_bundle_2020)
    @account.rollback(:invoke_touchstone)
  end
end
