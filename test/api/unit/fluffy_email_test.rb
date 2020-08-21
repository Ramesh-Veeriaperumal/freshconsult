require_relative '../unit_test_helper'
require_relative '../test_helper'
require 'sidekiq/testing'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class FluffyEmailTest < ActionView::TestCase
  include AccountHelper
  include EmailRateLimitTestHelper

  def setup
    @account = Account.first || create_test_account
    Account.stubs(:current).returns(@account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_enable_fluffy_for_email_with_plan_limit
    $redis_others.perform_redis_op('set', format(PLAN_EMAIL_LIMIT, plan_id: @account.subscription.plan_id), 200)
    $redis_others.perform_redis_op('hset', format(PLAN_EMAIL_PATHS_LIMIT, plan_id: @account.subscription.plan_id), 'EMAIL_SERVICE', fluffy_email_path_limit[:account_paths][0].to_json)
    $redis_others.perform_redis_op('hset', format(PLAN_EMAIL_PATHS_LIMIT, plan_id: @account.subscription.plan_id), 'EMAIL_SERVICE_SPAM', fluffy_email_path_limit[:account_paths][1].to_json)
    Fluffy::AccountsV2Api.any_instance.stubs(:add_application).returns(true)
    @account.enable_fluffy_for_email
    assert @account.fluffy_email_enabled?
  ensure
    $redis_others.perform_redis_op('del', format(PLAN_EMAIL_LIMIT, plan_id: @account.subscription.plan_id))
    $redis_others.perform_redis_op('hdel', format(PLAN_EMAIL_PATHS_LIMIT, plan_id: @account.subscription.plan_id), 'EMAIL_SERVICE')
    $redis_others.perform_redis_op('hdel', format(PLAN_EMAIL_PATHS_LIMIT, plan_id: @account.subscription.plan_id), 'EMAIL_SERVICE_SPAM')
    @account.rollback(:fluffy_email)
    Fluffy::AccountsV2Api.any_instance.unstub(:add_application)
  end

  def test_create_without_domain_or_limit
    refute Fluffy::FRESHDESK_EMAIL.create(nil, @account.id, nil, 'MINUTE', [])
  end

  def test_create_with_api_error
    Fluffy::AccountsV2Api.any_instance.stubs(:add_application).raises(Fluffy::ApiError.new)
    refute Fluffy::FRESHDESK_EMAIL.create(@account.full_domain, @account.id, 100, 'MINUTE', [])
  ensure
    Fluffy::AccountsV2Api.any_instance.unstub(:add_application)
  end

  def test_create_with_standard_error
    Fluffy::AccountsV2Api.any_instance.stubs(:add_application).raises(StandardError.new)
    refute Fluffy::FRESHDESK_EMAIL.create(@account.full_domain, @account.id, 100, 'MINUTE', [])
  ensure
    Fluffy::AccountsV2Api.any_instance.unstub(:add_application)
  end

  def test_update_without_domain_or_limit
    refute Fluffy::FRESHDESK_EMAIL.update(nil, @account.id, nil, 'MINUTE', [])
  end

  def test_enable_fluffy_for_email_without_plan_limit
    Fluffy::AccountsV2Api.any_instance.stubs(:add_application).returns(true)
    @account.enable_fluffy_for_email(500)
    assert @account.fluffy_email_enabled?
  ensure
    @account.rollback(:fluffy_email)
    Fluffy::AccountsV2Api.any_instance.unstub(:add_application)
  end

  def test_disable_fluffy_for_email
    Fluffy::AccountsV2Api.any_instance.stubs(:delete_account).returns(true)
    Fluffy::AccountsV2Api.any_instance.stubs(:add_application).returns(true)
    @account.enable_fluffy_for_email
    @account.disable_fluffy_for_email
    refute @account.fluffy_email_enabled?
  ensure
    Fluffy::AccountsV2Api.any_instance.unstub(:delete_account)
    Fluffy::AccountsV2Api.any_instance.unstub(:add_application)
  end

  def test_change_fluffy_email_limit_with_plan_limit
    Fluffy::AccountsV2Api.any_instance.stubs(:update_application).returns(true)
    @account.stubs(:fluffy_email_enabled?).returns(true)
    @account.change_fluffy_email_limit
  ensure
    @account.unstub(:fluffy_email_enabled?)
    Fluffy::AccountsV2Api.any_instance.unstub(:update_application)
  end

  def test_find_account
    fluffy_account = Fluffy::AccountV2.new(account_id: @account.id,
                                           name: @account.full_domain,
                                           limit: 100,
                                           granularity: 'MINUTE')
    Fluffy::AccountsV2Api.any_instance.stubs(:get_account).returns(fluffy_account)
    assert_equal fluffy_account, @account.current_fluffy_email_limit
  end
end
