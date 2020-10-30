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
    old_state = @account.subscription.state
    change_account_state(Subscription::TRIAL, @account) unless @account.subscription.trial?
    AccountCleanup::DeleteSpamTicketsCleanup.clear
    account_type = 'trial'
    CronWebhooks::AccountSpamCleanup.new.perform(type: account_type, task_name: 'account_cleanup_accounts_spam_cleanup')
    assert_equal Account.current_pod.safe_send("#{account_type}_accounts").count, AccountCleanup::DeleteSpamTicketsCleanup.jobs.size
  ensure
    change_account_state(old_state, @account) if @account.present?
  end
end
