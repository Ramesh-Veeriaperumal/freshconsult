require_relative '../test_helper'
require 'webmock/minitest'
require 'sidekiq/testing'
WebMock.allow_net_connect!
Sidekiq::Testing.fake!

class FreshcallerAccountTest < ActiveSupport::TestCase
  include FreshcallerAccountTestHelper
  include OmniChannelDashboard::Constants

  def setup
    super
    @account = @account.make_current
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
  end

  def teardown
    Account.unstub(:current)
  end

  def test_destroy_freshcaller_account
    fcaller_account = create_freshcaller_account @account
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
    fcaller_account.destroy
    assert_equal 1, CentralPublishWorker::FreshcallerAccountWorker.jobs.size
    job = CentralPublishWorker::FreshcallerAccountWorker.jobs.last
    assert_equal 'freshcaller_account_destroy', job['args'][0]
    job['args'][1]['model_properties'].must_match_json_expression(freshcaller_account_destroy_pattern(fcaller_account))
  ensure
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
  end

  def test_update_freshcaller_account
    @account.rollback(:omni_channel_dashboard)
    @account.launch(:omni_bundle_2020)
    @account.launch(:invoke_touchstone)
    old_subscription_id = @account.try(:subscription).try(:subscription_plan).try(:id)
    @account.subscription.subscription_plan.id = SubscriptionPlan.omni_channel_plan.map(&:id).first
    Account.any_instance.stubs(:omni_bundle_id).returns(123)
    @account.freshcaller_account&.destroy
    OmniChannelDashboard::AccountWorker.jobs.clear
    fcaller_account = create_freshcaller_account @account
    assert_equal 1, OmniChannelDashboard::AccountWorker.jobs.size
    assert_equal 'update', OmniChannelDashboard::AccountWorker.jobs.last['args'][0]['action']
  ensure
    @account.subscription.subscription_plan.id = old_subscription_id
    fcaller_account.destroy
    OmniChannelDashboard::AccountWorker.jobs.clear
    @account.rollback(:omni_bundle_2020)
    @account.rollback(:invoke_touchstone)
  end

  def test_create_freshcaller_account
    @account.freshcaller_account&.destroy
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
    fcaller_account = create_freshcaller_account @account
    assert_equal 1, CentralPublishWorker::FreshcallerAccountWorker.jobs.size
    payload = fcaller_account.central_publish_payload.to_json
    payload.must_match_json_expression(freshcaller_account_publish_pattern(fcaller_account))
    fcaller_account.destroy
  ensure
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
  end
end