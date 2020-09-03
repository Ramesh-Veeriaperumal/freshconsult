require_relative '../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require 'sidekiq/testing'

class PrecreateAccountsTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    ChargeBee::Customer.stubs(:update).returns(true)
    p 'Setup'
  end

  def teardown
    ChargeBee::Customer.unstub(:update)
    p 'teardown'
  end

  def test_precreate_accounts_default_domain
    populate_plans
    AccountCreation::PrecreateAccounts.new.perform(precreate_account_count: 1, shard_name: 'shard_1')
    current_precreated_account_length = $redis_others.perform_redis_op('llen', 'PRECREATED_ACCOUNTS:shard_1')
    assert_equal current_precreated_account_length, 1
  ensure
    $redis_others.perform_redis_op('del', 'PRECREATED_ACCOUNTS:shard_1')
  end

  def test_precreate_accounts_random_domain
    DomainGenerator.any_instance.stubs(:generate_default_precreate_domain).returns(nil)
    populate_plans
    AccountCreation::PrecreateAccounts.new.perform(precreate_account_count: 1, shard_name: 'shard_1')
    current_precreated_account_length = $redis_others.perform_redis_op('llen', 'PRECREATED_ACCOUNTS:shard_1')
    assert_equal current_precreated_account_length, 1
  ensure
    $redis_others.perform_redis_op('del', 'PRECREATED_ACCOUNTS:shard_1')
    DomainGenerator.any_instance.unstub(:generate_default_precreate_domain)
  end

  def test_precreate_accounts_with_invalid_input
    args = { precreate_account_count: 1, shard_name: 'invalid_shard' }
    AccountCreation::PrecreateAccounts.new.perform(args)
    current_precreated_account_length = $redis_others.perform_redis_op('llen', 'PRECREATED_ACCOUNTS:invalid_shard') || 0
    assert_equal current_precreated_account_length, 0
  end

  def test_precreate_accounts_with_exception
    Signup.any_instance.stubs(:save!).raises(StandardError)
    args = { precreate_account_count: 1, shard_name: 'shard_1' }
    AccountCreation::PrecreateAccounts.new.perform(args)
    current_precreated_account_length = $redis_others.perform_redis_op('llen', 'PRECREATED_ACCOUNTS:shard_1') || 0
    assert_equal current_precreated_account_length, 0
  ensure
    Signup.any_instance.unstub(:save!)
  end
end
