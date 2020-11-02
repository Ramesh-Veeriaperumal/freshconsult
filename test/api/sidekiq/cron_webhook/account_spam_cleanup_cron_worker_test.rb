require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class AccountSpamCleanupCronWorkerTest < ActionView::TestCase
  include AccountTestHelper
  def teardown
    super
    Account.unstub(:current)
  end

  def setup
    create_test_account if Account.first.nil?
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def test_trail_spam_cleanup_enqueue
    AccountCleanup::DeleteSpamTicketsCleanup.drain
    old_state = @account.subscription.state
    change_account_state(Subscription::TRIAL, @account) unless @account.subscription.trial?
    CronWebhooks::AccountSpamCleanup.new.perform(type: 'trial', task_name: 'account_cleanup_accounts_spam_cleanup')
    assert_equal 1, AccountCleanup::DeleteSpamTicketsCleanup.jobs.size
  ensure
    change_account_state(old_state, @account) if @account.present?
  end
end
