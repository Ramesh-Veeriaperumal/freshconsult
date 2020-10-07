require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require 'webmock/minitest'
Sidekiq::Testing.fake!
class CronApiWebhookWorkerTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    create_test_account if Account.first.nil?
    Account.stubs(:current).returns(Account.first)
    Subscription.any_instance.stubs(:switch_annual_notification_eligible?).returns(false)
    @account = Account.current
  end

  def teardown
    Subscription.any_instance.unstub(:switch_annual_notification_eligible?)
    super
  end

  def test_trail_cron_api_webhook_worker
    Admin::TrialSupervisorWorker.drain
    CronWebhooks::CronApiWebhookWorker.drain
    old_state = @account.subscription.state
    WebMock.stub_request(:post, 'http://127.0.0.1:8191/api/cron/trigger_cron_api').to_return(status: 200)
    Account.any_instance.stubs(:supervisor_enabled?).returns(true)
    Account.any_instance.stubs(:supervisor_rules).returns(['rules'])
    change_account_state(Subscription::TRIAL, @account) unless @account.subscription.trial?
    args = { 'actual_domain' => 'http://localhost.freshdesk-dev.com:3000', 'name' => 'supervisor', 'account_type' => 'trial' }
    CronWebhooks::CronApiWebhookWorker.new.perform(args)
    assert(true, 'This was expected to be true')
  ensure
    change_account_state(old_state, @account)
    Account.any_instance.unstub(:supervisor_enabled?)
    Account.any_instance.unstub(:supervisor_rules)
    Account.current.rollback(:cron_api_trigger)
  end

  def test_trail_cron_api_webhook_worker_400
    Admin::TrialSupervisorWorker.drain
    CronWebhooks::CronApiWebhookWorker.drain
    old_state = @account.subscription.state
    WebMock.stub_request(:post, 'http://127.0.0.1:8191/api/cron/trigger_cron_api').to_return(status: 400)
    Account.any_instance.stubs(:supervisor_enabled?).returns(true)
    Account.any_instance.stubs(:supervisor_rules).returns(['rules'])
    change_account_state(Subscription::TRIAL, @account) unless @account.subscription.trial?
    args = { 'actual_domain' => 'http://localhost.freshdesk-dev.com:3000', 'name' => 'supervisor', 'account_type' => 'trial' }
    CronWebhooks::CronApiWebhookWorker.new.perform(args)
    assert(true, 'This was expected to be true')
  ensure
    change_account_state(old_state, @account)
    Account.any_instance.unstub(:supervisor_enabled?)
    Account.any_instance.unstub(:supervisor_rules)
    Account.current.rollback(:cron_api_trigger)
  end
end
