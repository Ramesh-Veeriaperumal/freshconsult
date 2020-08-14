require_relative '../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class SuspendedAccountCleanupTest < ActionView::TestCase
  include AccountTestHelper
  def teardown
    Account.unstub(:current)
    super
  end

  def test_suspended_account_cleanup
    Account.stubs(:current).returns(Account.first)
    Subscription.any_instance.stubs(:updated_at).returns(6.months.ago - 3.days)
    Subscription.any_instance.stubs(:switch_annual_notification_eligible?).returns(false)
    @account = Account.current
    old_state = @account.subscription.state
    change_account_state(Subscription::SUSPENDED, @account)
    args = { 'account_id' => @account.id, 'enqueued_at' => Time.now.to_i }
    assert_nothing_raised do
      response = Ryuken::SuspendedAccountCleanup.new.perform(nil, args)
    end
  ensure
    change_account_state(old_state, @account) if @account.present?
    Subscription.any_instance.unstub(:updated_at)
    Subscription.any_instance.unstub(:switch_annual_notification_eligible?)
  end
end
