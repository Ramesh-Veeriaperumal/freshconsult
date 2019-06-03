require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'sandbox', 'provision_sandbox_test_helper.rb')

class UpdateSandboxSubscriptionTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    @production_account = AccountHelper.create_test_account
    super
  end

  def teardown
    Account.reset_current_account
    super
  end

  def test_suspending_sandbox_account
    Sharding.run_on_shard SANDBOX_SHARD_CONFIG do
      @sandbox_account = AccountHelper.create_test_account
      @sandbox_account.make_current
      Admin::Sandbox::UpdateSubscriptionWorker.new.perform(account_id: @production_account.id, sandbox_account_id: @sandbox_account.id, state: 'suspended')
      @sandbox_account.reload
      assert_equal @sandbox_account.subscription.state, 'suspended'
    end
  rescue StandardError => e
    { 'error' => e }
  end

  def test_activating_sandbox_account
    Sharding.run_on_shard SANDBOX_SHARD_CONFIG do
      @sandbox_account = AccountHelper.create_test_account
      @sandbox_account.make_current
      ::Admin::Sandbox::UpdateSubscriptionWorker.new.perform(account_id: @production_account.id, sandbox_account_id: @sandbox_account.id, state: 'trial')
      @sandbox_account.reload
      assert_equal @sandbox_account.subscription.state, 'trial'
    end
  rescue StandardError => e
    { 'error' => e }
  end
end
