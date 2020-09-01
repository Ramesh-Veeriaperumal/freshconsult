require_relative '../unit_test_helper'
require_relative '../test_helper'
require 'sidekiq/testing'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class FluffyApiTest < ActionView::TestCase
  include AccountHelper
  include RateLimitTestHelper

  def setup
    @account = Account.first || create_test_account
    Account.stubs(:current).returns(@account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_enable_fluffy_for_api_with_plan_limit
    $redis_others.perform_redis_op('set', format(PLAN_API_LIMIT, plan_id: @account.subscription.plan_id), 200)
    Fluffy::AccountsApi.any_instance.stubs(:add_application).returns(true)
    @account.enable_fluffy
    assert @account.fluffy_enabled?
  ensure
    $redis_others.perform_redis_op('del', format(PLAN_API_LIMIT, plan_id: @account.subscription.plan_id))
    @account.rollback(:fluffy)
    Fluffy::AccountsApi.any_instance.unstub(:add_application)
  end

  def test_enable_fluffy_min_for_api_with_plan_limit
    $redis_others.perform_redis_op('set', format(PLAN_API_MIN_LIMIT, plan_id: @account.subscription.plan_id), 200)
    $redis_others.perform_redis_op('hset', format(PLAN_API_MIN_PATHS_LIMIT, plan_id: @account.subscription.plan_id), 'TICKETS_LIST', fluffy_api_path_limit[:account_paths][0].to_json)
    $redis_others.perform_redis_op('hset', format(PLAN_API_MIN_PATHS_LIMIT, plan_id: @account.subscription.plan_id), 'CONTACTS_LIST', fluffy_api_path_limit[:account_paths][1].to_json)
    $redis_others.perform_redis_op('hset', format(PLAN_API_MIN_PATHS_LIMIT, plan_id: @account.subscription.plan_id), 'CREATE_TICKET', fluffy_api_path_limit[:account_paths][2].to_json)
    $redis_others.perform_redis_op('hset', format(PLAN_API_MIN_PATHS_LIMIT, plan_id: @account.subscription.plan_id), 'UPDATE_TICKET', fluffy_api_path_limit[:account_paths][3].to_json)
    Fluffy::AccountsApi.any_instance.stubs(:add_application).returns(true)
    @account.enable_fluffy_min_level
    assert @account.fluffy_min_level_enabled?
  ensure
    $redis_others.perform_redis_op('del', format(PLAN_API_MIN_LIMIT, plan_id: @account.subscription.plan_id))
    $redis_others.perform_redis_op('hdel', format(PLAN_API_MIN_PATHS_LIMIT, plan_id: @account.subscription.plan_id), 'TICKETS_LIST')
    $redis_others.perform_redis_op('hdel', format(PLAN_API_MIN_PATHS_LIMIT, plan_id: @account.subscription.plan_id), 'CONTACTS_LIST')
    $redis_others.perform_redis_op('hdel', format(PLAN_API_MIN_PATHS_LIMIT, plan_id: @account.subscription.plan_id), 'CREATE_TICKET')
    $redis_others.perform_redis_op('hdel', format(PLAN_API_MIN_PATHS_LIMIT, plan_id: @account.subscription.plan_id), 'UPDATE_TICKET')
    @account.rollback(:fluffy_min_level)
    Fluffy::AccountsApi.any_instance.unstub(:add_application)
  end

  def test_create_without_domain_or_limit
    refute Fluffy::FRESHDESK.create(nil, nil, 'MINUTE', [])
  end

  def test_update_without_domain_or_limit
    refute Fluffy::FRESHDESK.update(nil, nil, 'MINUTE', [])
  end

  def test_create_with_api_error
    Fluffy::AccountsApi.any_instance.stubs(:add_application).raises(Fluffy::ApiError.new)
    refute Fluffy::FRESHDESK.create(@account.full_domain, 100, 'MINUTE', [])
  ensure
    Fluffy::AccountsApi.any_instance.unstub(:add_application)
  end

  def test_create_with_standard_error
    Fluffy::AccountsApi.any_instance.stubs(:add_application).raises(StandardError.new)
    refute Fluffy::FRESHDESK.create(@account.full_domain, 100, 'MINUTE', [])
  ensure
    Fluffy::AccountsV2Api.any_instance.unstub(:add_application)
  end

  def test_enable_fluffy_for_api_without_plan_limit
    Fluffy::AccountsApi.any_instance.stubs(:add_application).returns(true)
    @account.enable_fluffy_min_level(500)
    assert @account.fluffy_min_level_enabled?
  ensure
    @account.rollback(:fluffy_min_level)
    Fluffy::AccountsApi.any_instance.unstub(:add_application)
  end

  def test_disable_fluffy_for_api
    Fluffy::AccountsApi.any_instance.stubs(:delete_account).returns(true)
    Fluffy::AccountsApi.any_instance.stubs(:add_application).returns(true)
    @account.enable_fluffy
    @account.disable_fluffy
    refute @account.fluffy_enabled?
  ensure
    @account.rollback(:fluffy)
    Fluffy::AccountsApi.any_instance.unstub(:delete_account)
    Fluffy::AccountsApi.any_instance.unstub(:add_application)
  end

  def test_disable_fluffy_min_for_api
    Fluffy::AccountsApi.any_instance.stubs(:delete_account).returns(true)
    Fluffy::AccountsApi.any_instance.stubs(:add_application).returns(true)
    @account.enable_fluffy_min_level
    @account.disable_fluffy_min_level
    refute @account.fluffy_min_level_enabled?
  ensure
    @account.rollback(:fluffy_min_level)
    Fluffy::AccountsApi.any_instance.unstub(:delete_account)
    Fluffy::AccountsApi.any_instance.unstub(:add_application)
  end

  def test_change_fluffy_api_limit_with_plan_limit
    Fluffy::AccountsApi.any_instance.stubs(:update_application).returns(true)
    @account.stubs(:fluffy_enabled?).returns(true)
    @account.change_fluffy_api_limit
  ensure
    @account.unstub(:fluffy_enabled?)
    Fluffy::AccountsApi.any_instance.unstub(:update_application)
  end

  def test_change_fluffy_min_api_limit_with_plan_limit
    Fluffy::AccountsApi.any_instance.stubs(:update_application).returns(true)
    @account.stubs(:fluffy_min_level_enabled?).returns(true)
    assert @account.change_fluffy_api_min_limit
  ensure
    @account.unstub(:fluffy_min_level_enabled?)
    Fluffy::AccountsApi.any_instance.unstub(:update_application)
  end

  def test_find_account
    fluffy_account = Fluffy::Account.new(name: @account.full_domain,
                                         limit: 100,
                                         granularity: 'MINUTE')
    Fluffy::AccountsApi.any_instance.stubs(:find_application).returns(fluffy_account)
    assert_equal fluffy_account, @account.current_fluffy_limit
  ensure
    Fluffy::AccountsApi.any_instance.unstub(:find_application)
  end
end
