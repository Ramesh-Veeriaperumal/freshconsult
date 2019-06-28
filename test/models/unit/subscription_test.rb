require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class SubscriptionTest < ActiveSupport::TestCase
  include AccountTestHelper

  def test_update_should_not_change_onboarding_state_for_active_accounts
    create_new_account('test1234', 'test1234@freshdesk.com')
    update_currency
    agent = @account.agents.first.user
    User.stubs(:current).returns(agent)
    Subscription.any_instance.stubs(:state).returns('active')
    subscription = @account.subscription
    @account.set_account_onboarding_pending
    assert_equal @account.onboarding_pending?, true
    subscription.plan = SubscriptionPlan.current.last
    subscription.save
    assert_equal @account.onboarding_pending?, true
  ensure
    Subscription.any_instance.unstub(:state)
    User.unstub(:current)
    @account.destroy
  end

  def test_update_changes_onboarding_state
    create_new_account('test1234', 'test1234@freshdesk.com')
    update_currency
    agent = @account.agents.first.user
    User.stubs(:current).returns(agent)
    subscription = @account.subscription
    @account.set_account_onboarding_pending
    assert_equal @account.onboarding_pending?, true
    subscription.plan = SubscriptionPlan.current.last
    subscription.state = 'active'
    subscription.save
    assert_equal @account.onboarding_pending?, false
  ensure
    User.unstub(:current)
    @account.destroy
  end
end
