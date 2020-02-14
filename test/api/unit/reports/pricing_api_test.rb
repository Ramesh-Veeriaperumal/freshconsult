require_relative '../../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class Reports::PricingApiTest < ActiveSupport::TestCase
  include AccountTestHelper
  include Reports::Pricing::Api
  include HelpdeskReports::Constants::FreshvisualFeatureMapping

  def setup
    if @account.blank?
      create_test_account
      @account = Account.current
      @account.save
    end
  end

  def tear_down
    Account.reset_current_account
  end

  def test_payload_with_all_feature_addition
    curated_reports_list = FD_FRESVISUAL_FEATURE_MAPPING.keys.select do |k|
      v = FD_FRESVISUAL_FEATURE_MAPPING[k]
      v.class == Array ? v.any? {|v| v[:config_type] == :curated_reports} : v[:config_type] == :curated_reports
    end
    stub_faraday do
      curated_reports_list.each do |f|
        Account.any_instance.stubs("#{f}_enabled?".to_sym).returns(true)
      end

      payload = self.safe_send(:construct_restrictions_payload)
      assert_equal payload[:curatedRestrictions].size, 0
      assert_equal payload[:resourceRestrictions].size, 0
    end
  ensure
    curated_reports_list.each do |f|
      Account.any_instance.unstub("#{f}_enabled?".to_sym)
    end
  end

  def test_payload_with_no_feature_addition
    stub_faraday do
      FD_FRESVISUAL_FEATURE_MAPPING.keys.each do |f|
        Account.any_instance.stubs("#{f}_enabled?".to_sym).returns(false)
      end

      config_payload = JSON.parse(CONFIG_PAYLOAD).deep_symbolize_keys
      config_payload[:curatedRestrictions] = []
      config_payload[:resourceRestrictions] = []

      payload = self.safe_send(:construct_restrictions_payload)
      
      assert_equal payload[:curatedRestrictions].size, CURATED_REPORTS_LIST.size
      assert_equal payload[:resourceRestrictions].size, RESOURCE_RESTRICTION_LIST.size   
    end
  ensure
    FD_FRESVISUAL_FEATURE_MAPPING.keys.each do |f|
      Account.any_instance.unstub("#{f}_enabled?".to_sym)
    end
  end

  def test_enable_only_curated_reports
    stub_faraday do
      FD_FRESVISUAL_FEATURE_MAPPING.keys.each do |f|
        config = FD_FRESVISUAL_FEATURE_MAPPING[f]
        if config.class == Array
          Account.any_instance.stubs("#{f}_enabled?".to_sym).returns(false)
        else
          value = config[:config_type] == CONFIG_TYPES[:CURATED_REPORTS] ? true : false
          Account.any_instance.stubs("#{f}_enabled?".to_sym).returns(true)
        end
      end

      payload = self.safe_send(:construct_restrictions_payload)
      assert_equal payload[:resourceRestrictions].size, 0
    end
  ensure
    FD_FRESVISUAL_FEATURE_MAPPING.keys.each do |f|
      Account.any_instance.unstub("#{f}_enabled?".to_sym)
    end
  end 

  def test_create_tenant_upsert_success_response
    mock = Minitest::Mock.new
    Faraday::Connection.any_instance.stubs(:put).returns(Faraday::Response.new({status: 200}))
    mock.expect(:call, nil, ["Reports pricing API called :: tenant_put, for Account #{Account.current.id}"])
    Rails.logger.stub :debug, mock do
      self.safe_send(:create_tenant)
    end
    assert_equal mock.verify, true
  end

  def test_create_tenant_upsert_failure_response
    mock = Minitest::Mock.new
    Faraday::Connection.any_instance.stubs(:put).returns(Faraday::Response.new({status: 422}))
    mock.expect(:call, nil, ["Pricing API: Exception in log_request_and_call :: tenant_put, error: Pricing API Invalid response, code: 422 for Account #{Account.current.id}" ])
    Rails.logger.stub :error, mock do
      self.safe_send(:create_tenant)
    end
    assert_equal mock.verify, true
  end

  def test_worker_enqueue_on_feature_addition
    @account.revoke_feature(:analytics_report_save)
    Account.current.stubs(:freshvisual_configs_enabled?).returns(true)
    Reports::FreshvisualConfigs.jobs.clear
    @account.add_feature :analytics_report_save
    assert_equal Reports::FreshvisualConfigs.jobs.size, 1
  ensure
    @account.revoke_feature :analytics_report_save
    Account.current.unstub(:freshvisual_configs_enabled?)
  end

  private

    def stub_faraday
      Faraday::Connection.any_instance.stubs(:put).returns('{}')
      Faraday::Connection.any_instance.stubs(:post).returns('{}')
      yield
      Faraday::Connection.any_instance.unstub(:put)
      Faraday::Connection.any_instance.unstub(:post)
    end
end
