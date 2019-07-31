require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

Sidekiq::Testing.fake!

class RollbackTrialSubscriptionsDataTest < ActionView::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.current
    @user = @account.nil? ? create_test_account : add_new_user(@account)
    @user.make_current
    Account.current.launch TrialSubscription::TRIAL_SUBSCRIPTION_LP_FEATURE
  end

  def get_valid_plan_name
    SubscriptionPlan.where(classic: false).pluck(:name).first
  end

  def create_trial_subscription
    t = TrialSubscription.new(
      ends_at: Time.now.utc - TrialSubscription::TRIAL_INTERVAL_IN_DAYS.days / 2,
      from_plan: get_valid_plan_name,
      trial_plan: get_valid_plan_name,
      account_id: Account.current.id,
      actor_id: Account.current.account_managers.first.id,
      status: TrialSubscription::TRIAL_STATUSES[:active]
    )
    t.save!
  end

  def test_rollback_trail_subscriptions_data
    create_trial_subscription
    trial_subscription_id = TrialSubscription.last.id
    TrialSubscription.stubs(:ending_trials).returns(TrialSubscription)
    ActiveRecord::Base.stubs(:supports_sharding?).returns(false)
    CronWebhooks::RollbackTrialSubscriptionsData.new.perform(task_name: 'trial_subscriptions_rollback_trail_subscriptions_data')
    assert TrialSubscription::TRIAL_STATUSES[:inactive] == TrialSubscription.find(trial_subscription_id).status
    ActiveRecord::Base.unstub(:supports_sharding?)
    TrialSubscription.unstub(:ending_trials)
  end
end
