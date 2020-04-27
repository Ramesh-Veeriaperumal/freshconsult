require_relative '../api/unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'lib', 'helpers', 'va_rules_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class ThrottlerTest < ActionView::TestCase
  include ::AccountTestHelper
  include VaRulesTesthelper
  include Redis::RedisKeys
  include Redis::PortalRedis
  include Redis::OthersRedis

  def setup
    super
    @account = Account.first || create_new_account
    @account.launch(:cre_account)
    Account.any_instance.stubs(:current).returns(@account)
  end

  def teardown
    Account.any_instance.stubs(:current)
    super
  end

  def construct_args(va_rule)
    {
      'ticket_id': 1,
      'account_id': @account.id,
      'rule_id': va_rule.id,
      'webhook_created_at': Time.now.utc
    }
  end

  def test_webhook_limit_is_posted_to_central_worker
    CentralPublish::CRECentralWorker.jobs.clear
    va_rule = create_rule_with_type(VAConfig::OBSERVER_RULE, @account.id)
    args = construct_args(va_rule)
    args = args.stringify_keys
    Middleware::Sidekiq::Server::Throttler.new({}).notify_cre_webhook_limit(args, false)
    assert_equal 1, CentralPublish::CRECentralWorker.jobs.size
    CentralPublish::CRECentralWorker.jobs.clear
  end

  def test_webhook_dropoff_is_posted_to_central_worker
    CentralPublish::CRECentralWorker.jobs.clear
    va_rule = create_rule_with_type(VAConfig::OBSERVER_RULE, @account.id)
    args = construct_args(va_rule)
    args = args.stringify_keys
    $redis_others.perform_redis_op('set', format(WEBHOOK_DROP_NOTIFY, account_id: args['account_id']), 0)
    Middleware::Sidekiq::Server::Throttler.new({}).notify_webhook_drop(args)
    assert_equal 1, CentralPublish::CRECentralWorker.jobs.size
    CentralPublish::CRECentralWorker.jobs.clear
  end
end
