require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
Sidekiq::Testing.fake!
class RollbackTrialSubscriptionsCronTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    @user = @account.nil? ? create_test_account : add_new_user(@account)
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def test_trail_downgrade
    trial_subscription = FactoryGirl.build(:trial_subscription,
                                           trial_plan: SubscriptionPlan.last.name,
                                           account_id: Account.current.id, actor_id: @user.id,
                                           ends_at: (Time.now - 2.days).to_date,
                                           status:  0, from_plan: SubscriptionPlan.first.name)
    trial_subscription.save
    CronWebhooks::RollbackTrialSubscriptionsData.new.perform(task_name: 'trial_subscriptions_rollback_trail_subscriptions_data')
    trial_subscription.reload
    assert_equal TrialSubscription::TRIAL_STATUSES[:inactive], trial_subscription.status, 'Trial was not downgraded'
  ensure
    trial_subscription.destroy
  end
end
