# frozen_string_literal: true

require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class OmniAccountsMonitoringInternalReportsWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include Redis::Keys::Others

  def test_reports_when_email_is_non_empty
    CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.any_instance.stubs(:get_all_members_in_a_redis_set).with(OMNI_ACCOUNTS_MONITORING_MAILING_LIST).returns(['sample.1@freshdesk.com'])
    OmniChannel::EmailUtil::Emailer.any_instance.expects(:export_data).times(1)
    CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.drain
    CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.new.perform(type: 'trial', task_name: 'omni_accounts_monitoring_internal_reports')
  ensure
    CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.any_instance.unstub(:get_all_members_in_a_redis_set)
  end

  def test_reports_when_email_is_empty
    CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.any_instance.stubs(:get_all_members_in_a_redis_set).with(OMNI_ACCOUNTS_MONITORING_MAILING_LIST).returns([])
    OmniChannel::EmailUtil::Emailer.any_instance.expects(:export_data).times(0)
    CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.drain
    CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.new.perform(type: 'trial', task_name: 'omni_accounts_monitoring_internal_reports')
  ensure
    CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.any_instance.unstub(:get_all_members_in_a_redis_set)
  end

  def test_reports_when_kill_switch_is_set
    CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.any_instance.stubs(:redis_key_exists?).with(OMNI_ACCOUNTS_MONITORING_STOP_EXECUTION).returns(true)
    CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.drain
    CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.expects(:init).times(0)
    CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.new.perform(type: 'trial', task_name: 'omni_accounts_monitoring_internal_reports')
  ensure
    CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.any_instance.unstub(:redis_key_exists)
  end

  def test_start_time_for_report_with_no_key_set
    instance = CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.new
    start_time = instance.safe_send(:start_time_for_reports)
    assert 4.hours.ago >= start_time, 'Should be greater than or equal to 4 hours'
  end

  def test_start_time_for_report_with_key_set_less_than_720_hours
    instance = CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.new
    instance.stubs(:get_others_redis_key).returns('22')
    start_time = instance.safe_send(:start_time_for_reports)
    assert 20.hours.ago > start_time, 'Should be greater than 20 hours'
  ensure
    instance.unstub(:get_others_redis_key)
  end

  def test_start_time_for_report_with_key_set_greater_than_720_hours
    instance = CronWebhooks::OmniAccountsMonitoringInternalReportsWorker.new
    instance.stubs(:get_others_redis_key).returns('722')
    start_time = instance.safe_send(:start_time_for_reports)
    assert 4.hours.ago >= start_time, 'Should be greater than or equal to 4 hours'
  ensure
    instance.unstub(:get_others_redis_key)
  end
end
