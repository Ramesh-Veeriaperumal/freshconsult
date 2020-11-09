# frozen_string_literal: true

require_relative '../../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class KbserviceClearCacheWorkerTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.first || create_test_account
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_clear_cache
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    stub_kb_service_cache_clear_endpoint_200
    stub_connection
    Sidekiq::Testing.inline! do
      Solution::KbserviceClearCacheWorker.perform_async(entity: 'article')
      NewRelic::Agent.expects(:notice_error).never
    end
  ensure
    unstub_connection
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
  end

  def test_clear_cache_with_error_response
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    stub_kb_service_cache_clear_endpoint_500
    stub_connection
    Sidekiq::Testing.inline! do
      NewRelic::Agent.expects(:notice_error).at_least_once
      Solution::KbserviceClearCacheWorker.perform_async(entity: 'article')
    end
  ensure
    unstub_connection
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
  end

  def test_clear_cache_without_kbservice_endpoint
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    stub_kb_service_cache_clear_endpoint_500
    Solution::KbserviceClearCacheWorker.any_instance.stubs(:kbservice_connection).returns(nil)
    Sidekiq::Testing.inline! do
      NewRelic::Agent.expects(:notice_error).at_least_once
      Solution::KbserviceClearCacheWorker.perform_async(entity: 'article')
    end
  ensure
    unstub_connection
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
  end

  def test_clear_cache_without_kbservice_endpoint_without_feature
    stub_kb_service_cache_clear_endpoint_500
    Sidekiq::Testing.inline! do
      Solution::KbserviceClearCacheWorker.perform_async(entity: 'article')
      NewRelic::Agent.expects(:notice_error).never
    end
  ensure
    unstub_connection
  end

  def stubs
    @stubs ||= Faraday::Adapter::Test::Stubs.new
  end

  def stub_connection
    faraday_stub = Faraday.new do |builder|
      builder.adapter :test, stubs
    end
    Solution::KbserviceClearCacheWorker.any_instance.stubs(:kbservice_connection).returns(faraday_stub)
  end

  def unstub_connection
    Solution::KbserviceClearCacheWorker.any_instance.unstub(:kbservice_connection)
  end

  def stub_kb_service_cache_clear_endpoint_200
    stubs.post('/solutions/api/v2/accounts/clear_cache') do |env|
      [200, {}, {
        status_code: 200
      }.to_json]
    end
  end

  def stub_kb_service_cache_clear_endpoint_500
    stubs.post('/solutions/api/v2/accounts/clear_cache') do |env|
      [500, {}, {
        status_code: 500
      }.to_json]
    end
  end
end
