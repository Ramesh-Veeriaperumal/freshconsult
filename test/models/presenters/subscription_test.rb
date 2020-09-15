require_relative '../test_helper'

class SubscriptionTest < ActiveSupport::TestCase
  include SubscriptionTestHelper

  def test_subscription_update_with_feature
    CentralPublisher::Worker.jobs.clear
    update_subscription
    assert_equal 1, CentralPublisher::Worker.jobs.size
    subscription = Account.current.subscription
    payload = subscription.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_post_pattern(subscription))
    event_info = subscription.event_info(:update)
    event_info.must_match_json_expression(event_info_pattern)
  end

  def test_publish_for_suspended_account?
    Account.stubs(:current).returns(Account.first || create_test_account)
    Subscription.any_instance.stubs(:suspended?).returns(true)
    pass_value = Subscription.disallow_payload?('subscription_update')
    assert_equal false, pass_value
    Account.unstub(:current)
    Subscription.any_instance.unstub(:suspended?)
  end

  def test_publish_for_suspended_account_fail
    Account.stubs(:current).returns(Account.first || create_test_account)
    Subscription.any_instance.stubs(:suspended?).returns(true)
    pass_value = Subscription.disallow_payload?('default_value')
    assert_equal true, pass_value
    Account.unstub(:current)
    Subscription.any_instance.unstub(:suspended?)
  end

  def test_publish_when_removing_all_addons
    removed_addon_model_changes = { added: [], removed: [{ name: 'Freddy Ultimate', additional_info: { included_sessions: 5000 } }, { name: 'Freddy Session Packs Monthly', quantity: 0, additional_info: { included_sessions: 0 } }], updated: [] }
    old_addons = Subscription::Addon.where(name: ['Freddy Session Packs Monthly', 'Freddy Ultimate'])
    Subscription.any_instance.stubs(:state).returns('active')
    Subscription.any_instance.stubs(:addons).returns(old_addons).then.returns([])
    subscription = Account.current.subscription
    subscription.addons = []
    subscription.freddy_session_packs = 1000
    subscription.save
    assert subscription.addon_changes_for_central[:addons] == removed_addon_model_changes
  ensure
    Subscription.any_instance.unstub(:addons)
    Subscription.any_instance.unstub(:state)
  end

  def test_publish_when_adding_addons
    added_addon_model_changes = { added: [{ name: 'Freddy Ultimate', quantity: 15, additional_info: { included_sessions: 5000 } }, { name: 'Freddy Session Packs Monthly', quantity: 0, additional_info: { included_sessions: 0 } }], removed: [], updated: [] }
    new_addons = Subscription::Addon.where(name: ['Freddy Session Packs Monthly', 'Freddy Ultimate'])
    Subscription.any_instance.stubs(:state).returns('active')
    Subscription.any_instance.stubs(:agent_limit).returns(15)
    Subscription.any_instance.stubs(:addons).returns([]).then.returns(new_addons)
    subscription = Account.current.subscription
    subscription.addons = []
    subscription.freddy_sessions = 10
    subscription.save
    assert subscription.addon_changes_for_central[:addons] == added_addon_model_changes
  ensure
    Subscription.any_instance.unstub(:addons)
    Subscription.any_instance.unstub(:state)
    Subscription.any_instance.unstub(:agent_limit)
  end
end
