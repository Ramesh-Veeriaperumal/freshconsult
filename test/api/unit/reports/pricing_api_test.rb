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
    Reports::FreshvisualConfigs.jobs.clear
    @account.add_feature :analytics_report_save
    assert_equal Reports::FreshvisualConfigs.jobs.size, 1
  ensure
    @account.revoke_feature :analytics_report_save
  end

  def test_csv_export_presence_when_upgraded_19
    Account.stubs(:current).returns(@account)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.where(name:'Sprout Jan 19').first.id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.where(name: 'Blossom Jan 19').first.id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert @account.has_feature? :analytics_widget_export
  ensure
  	Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_worker_enqueue_on_kbanalytics_feature_addition
    @account.revoke_feature(:analytics_knowledge_base)
    @account.revoke_feature(:analytics_articles)
    Reports::FreshvisualConfigs.jobs.clear
    @account.add_feature :analytics_articles
    assert_equal Reports::FreshvisualConfigs.jobs.size, 1
  ensure
    @account.revoke_feature :analytics_articles
    @account.revoke_feature :analytics_knowledge_base
  end

  def test_worker_enqueue_on_triage_feature_addition
    @account.revoke_feature(:triage)
    Reports::FreshvisualConfigs.jobs.clear
    @account.add_feature :triage
    assert_equal Reports::FreshvisualConfigs.jobs.size, 1
  ensure
    @account.revoke_feature :triage
  end

  def test_kbanalytics_feature_upgrade_secondary
    Account.stubs(:current).returns(@account)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.where(name: 'Blossom Jan 20').first.id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.where(name: 'Garden Jan 20').first.id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert_equal(@account.has_feature?(:analytics_articles), true)
    assert_equal(@account.has_feature?(:analytics_knowledge_base), false)
    assert_equal(@account.has_feature?(:analytics_knowledge_base_report), true)
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_kbanalytics_feature_upgrade
    Account.stubs(:current).returns(@account)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.where(name: 'Garden Jan 20').first.id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.where(name: 'Forest Jan 20').first.id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert_equal(@account.has_feature?(:analytics_articles), true)
    assert_equal(@account.has_feature?(:analytics_knowledge_base), true)
    assert_equal(@account.has_feature?(:analytics_knowledge_base_report), false)
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_kbanalytics_feature_downgrade
    Account.stubs(:current).returns(@account)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.where(name: 'Forest Jan 20').first.id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.where(name: 'Garden Jan 20').first.id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert_equal(@account.has_feature?(:analytics_articles), true)
    assert_equal(@account.has_feature?(:analytics_knowledge_base), false)
    assert_equal(@account.has_feature?(:analytics_knowledge_base_report), true)
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_kbanalytics_feature_downgrade_secondary
    Account.stubs(:current).returns(@account)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.where(name: 'Garden Jan 20').first.id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.where(name: 'Blossom Jan 20').first.id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert_equal(@account.has_feature?(:analytics_articles), false)
    assert_equal(@account.has_feature?(:analytics_knowledge_base), false)
    assert_equal(@account.has_feature?(:analytics_knowledge_base_report), false)
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_timesheets_tabular_presence_when_upgraded_19
    Account.stubs(:current).returns(@account)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.where(name: 'Sprout Jan 19').first.id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.where(name: 'Blossom Jan 19').first.id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert @account.has_feature? :timesheets
    assert @account.has_feature? :analytics_widget_show_tabular_data
    assert @account.has_feature? :analytics_widget_edit_tabular_data
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_csv_export_absence_when_downgraded_19
    Account.stubs(:current).returns(@account)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.where(name: 'Blossom Jan 19').first.id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.where(name: 'Sprout Jan 19').first.id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert_equal(@account.has_feature?(:analytics_widget_export), false)
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_timesheets_tabular_absence_when_downgraded_19
    Account.stubs(:current).returns(@account)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.where(name: 'Blossom Jan 19').first.id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.where(name: 'Sprout Jan 19').first.id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert_equal(@account.has_feature?(:timesheets), false)
    assert_equal(@account.has_feature?(:analytics_widget_show_tabular_data), false)
    assert_equal(@account.has_feature?(:analytics_widget_edit_tabular_data), false)
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_csv_export_presence_when_upgraded_20
    Account.stubs(:current).returns(@account)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.where(name: 'Sprout Jan 20').first.id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.where(name: 'Blossom Jan 20').first.id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert @account.has_feature? :analytics_widget_export
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_timesheets_tabular_presence_when_upgraded_20
    Account.stubs(:current).returns(@account)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.where(name: 'Sprout Jan 20').first.id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.where(name: 'Blossom Jan 20').first.id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert @account.has_feature? :timesheets
    assert @account.has_feature? :analytics_widget_show_tabular_data
    assert @account.has_feature? :analytics_widget_edit_tabular_data
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_csv_export_absence_when_downgraded_20
    Account.stubs(:current).returns(@account)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.where(name: 'Blossom Jan 20').first.id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.where(name: 'Sprout Jan 20').first.id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert_equal(@account.has_feature?(:analytics_widget_export), false)
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_timesheets_tabular_absence_when_downgraded_20
    Account.stubs(:current).returns(@account)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.where(name: 'Blossom Jan 20').first.id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.where(name: 'Sprout Jan 20').first.id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert_equal(@account.has_feature?(:timesheets), false)
    assert_equal(@account.has_feature?(:analytics_widget_show_tabular_data), false)
    assert_equal(@account.has_feature?(:analytics_widget_edit_tabular_data), false)
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
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
