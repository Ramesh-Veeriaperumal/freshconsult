require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require 'webmock/minitest'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

Sidekiq::Testing.fake!

class UpdateAccountDomainTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    super
    @account = Account.current || create_account_if_not_exists
  end

  def teardown
    super
  end

  def create_account_if_not_exists
    user = create_test_account
    user.account
  end

  def test_update_domain_successful_update
    ChargeBee::Customer.stubs(:update).returns(true)
    assert_nothing_raised do
      Billing::UpdateAccountDomain.new.perform
    end
  ensure
    ChargeBee::Customer.unstub(:update)
  end

  def test_update_domain_raises_exception
    ChargeBee::Customer.stubs(:update).raises(StandardError)
    assert_raise StandardError do
      Billing::UpdateAccountDomain.new.perform
    end
  ensure
    ChargeBee::Customer.unstub(:update)
  end
end
