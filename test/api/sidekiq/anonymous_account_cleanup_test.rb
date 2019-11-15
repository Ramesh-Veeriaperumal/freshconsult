require_relative '../unit_test_helper'
require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

require 'sidekiq/testing'
Sidekiq::Testing.fake!

class AnonymousAccountCleanupTest < ActionView::TestCase
  include AccountTestHelper
  def test_non_anonymous_account_cleanup
    account = create_new_account(Faker::Lorem.word, Faker::Internet.email) if @account.blank? || @account.anonymous_account?
    account_id = @account.id
    args = { account_id: account_id }
    ChargeBee::Subscription.any_instance.stubs(:cancel_subscription).returns(true)
    Sidekiq::Testing.inline! do
      AccountCleanup::AnonymousAccountCleanup.new.perform(args)
    end
    assert_not_nil Account.find_by_id(account_id)
  ensure
    ChargeBee::Subscription.any_instance.unstub(:cancel_subscription)
    account.destroy if account
  end

  def test_anonymous_account_cleanup
    create_sample_account(Faker::Lorem.word, Faker::Internet.email)
    account_id = @account.id
    @account.reload
    @account.account_additional_settings.mark_account_as_anonymous
    Account.stubs(:current).returns(@account.reload)
    args = { account_id: @account.id }
    Sidekiq::Testing.inline! do
      AccountCleanup::AnonymousAccountCleanup.new.perform(args)
    end
    account = Account.find_by_id(account_id)
    assert_nil account
  ensure
    Account.unstub(:current)
    account.destroy if account
  end
end
