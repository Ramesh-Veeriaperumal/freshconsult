require_relative '../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')
class SchedulerDowngradePolicyReminderTest < ActionView::TestCase
  include AccountTestHelper
  include SubscriptionTestHelper
  def teardown
    Account.unstub(:current)
    super
  end

  def test_scheduler_downgrade_policy_reminder
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @account.launch(:downgrade_policy)
    current_subscription = @account.subscription
    new_reminder = get_new_subscription_request(@account, current_subscription.subscription_plan_id - 1, current_subscription.renewal_period)
    args = { 'account_id' => @account.id, 'enqueued_at' => Time.now.to_i }
    assert_nothing_raised do
      response = Ryuken::SchedulerDowngradePolicyReminder.new.perform(nil, args)
    end
  end
end
