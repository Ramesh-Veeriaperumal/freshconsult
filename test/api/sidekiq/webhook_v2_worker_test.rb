# frozen_string_literal: true

require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'lib', 'helpers', 'va_rules_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class WebhookV2WorkerTest < ActionView::TestCase
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
      'webhook_created_at': Time.now.utc,
      'params': {
        'domain': 'localhost.freshpo.com'
      },
      'auth_header': {},
      'webhook_validation_enabled': false,
      'retry_count': 4,
      'webhook_limit': 1000
    }
  end

  def test_webhook
    CentralPublish::CRECentralWorker.jobs.clear
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 201)
    TenantRateLimiter::AccountWebhookV2Worker.stubs(:perform_async).returns(true)
    va_rule = create_rule_with_type(VAConfig::OBSERVER_RULE, @account.id)
    args = construct_args(va_rule)
    TenantRateLimiter::Iterable::RedisSortedSet.any_instance.stubs(:fetch_jobs).returns([args.to_json])
    WebhookV2Worker.perform_async(args)
    TenantRateLimiter::AccountWebhookV2Worker.new.perform(args.merge(WebhookV2Worker.iterable_options(args)))
    assert_equal 0, CentralPublish::CRECentralWorker.jobs.size
  ensure
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
    TenantRateLimiter::AccountWebhookV2Worker.unstub(:perform_async)
    TenantRateLimiter::Iterable::RedisSortedSet.any_instance.unstub(:fetch_jobs)
    CentralPublish::CRECentralWorker.jobs.clear
  end

  def test_webhook_failure_is_posted_to_central_worker
    CentralPublish::CRECentralWorker.jobs.clear
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 400)
    TenantRateLimiter::AccountWebhookV2Worker.stubs(:perform_async).returns(true)
    va_rule = create_rule_with_type(VAConfig::OBSERVER_RULE, @account.id)
    args = construct_args(va_rule)
    TenantRateLimiter::Iterable::RedisSortedSet.any_instance.stubs(:fetch_jobs).returns([args.to_json])
    WebhookV2Worker.perform_async(args)
    TenantRateLimiter::AccountWebhookV2Worker.new.perform(args.merge(WebhookV2Worker.iterable_options(args)))
    assert_equal 1, CentralPublish::CRECentralWorker.jobs.size
  ensure
    CentralPublish::CRECentralWorker.jobs.clear
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
    TenantRateLimiter::AccountWebhookV2Worker.unstub(:perform_async)
    TenantRateLimiter::Iterable::RedisSortedSet.any_instance.unstub(:fetch_jobs)
  end
end
