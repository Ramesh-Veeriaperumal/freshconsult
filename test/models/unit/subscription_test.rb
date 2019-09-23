require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class SubscriptionTest < ActiveSupport::TestCase
  include AccountTestHelper
  include SocialTicketsCreationHelper

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

  def test_ticket_creation_on_omniplan_change
    create_new_account('test1234', 'test1234@freshdesk.com')
    update_currency
    agent = @account.agents.first.user
    User.stubs(:current).returns(agent)
    ProductFeedbackWorker.expects(:perform_async).once
    subscription = @account.subscription
    subscription.plan = SubscriptionPlan.current.find_by_name 'Garden Omni Jan 19'
    subscription.state = 'active'
    subscription.save
  ensure
    User.unstub(:current)
    @account.destroy
  end

  def test_ticket_creation_not_triggered_on_non_omniplan_change
    create_new_account('test1234', 'test1234@freshdesk.com')
    update_currency
    agent = @account.agents.first.user
    User.stubs(:current).returns(agent)
    ProductFeedbackWorker.expects(:perform_async).never
    subscription = @account.subscription
    subscription.plan = SubscriptionPlan.current.find_by_name 'Garden Jan 19'
    subscription.state = 'active'
    subscription.save
  ensure
    User.unstub(:current)
    @account.destroy
  end

  def test_omni_channel_ticket_params_method
    account = Account.first.make_current
    subscription = account.subscription
    description = subscription.omni_channel_ticket_params(account, subscription, nil)[:description]
    assert_equal description, "Customer has switched to / purchased an Omni-channel Freshdesk plan. <br>     <b>Account ID</b> : #{account.id}<br><b>Domain</b> : #{account.full_domain}<br><b>Current plan</b>     : #{subscription.plan_name}<br><b>Currency</b> : #{account.subscription.currency.name}<br><b>Previous plan</b> :     #{subscription.plan_name}<br><b>Contact</b> : <br>Ensure plan is set correctly in chat and caller."
  end

  def test_account_suspended_do_not_unsubscribe_twitter
    create_test_account
    create_social_streams
    subscription = @account.subscription
    @old_state = subscription.state
    subscription.state = 'suspended'
    subscription.save
    assert_equal @account.twitter_handles.present?, true
    assert_equal @account.twitter_streams.present?, true
    assert_equal @account.custom_twitter_streams.present?, true
  ensure
    subscription = @account.subscription
    subscription.state = @old_state
    subscription.save
  end

  def create_social_streams
    twitter_handle = FactoryGirl.build(:seed_twitter_handle)
    twitter_handle.account_id = @account.id
    twitter_handle.save!
    custom_stream = FactoryGirl.build(:seed_twitter_stream)
    custom_stream.account_id = @account.id
    custom_stream.social_id = nil
    custom_stream.save!
    custom_stream.populate_accessible(Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all])
  end
end
