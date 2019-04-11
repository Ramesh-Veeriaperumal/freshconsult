require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require 'webmock/minitest'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class AuditLogExportTest < ActiveSupport::TestCase
  include AccountTestHelper

  def setup
    @account = Account.first.make_current
  end

  def test_audit_log_export_with_logs
    WebMock.allow_net_connect!
    HTTParty.stubs(:get).returns(HTTParty, true)
    HTTParty.stubs(:body).returns({ status: 200, data: { export_url: 'dummy_url' }.stringify_keys! }.to_json)
    AuditLogExport.any_instance.stubs(:export_csv).returns(true)
    AuditLogExport.any_instance.stubs(:upload_file).returns(true)
    AwsWrapper::S3Object.stubs(:store).returns(true)
    args = construct_args_with_logs
    account = Account.first.nil? ? Account.first : create_test_account
    Account.stubs(:current).returns(Account.first)
    value = AuditLogExport.new.perform(args)
    WebMock.disable_net_connect!
  ensure
    Export::Util.unstub(:build_attachment)
    Account.unstub(:current)
    User.unstub(:current)
  end

  def test_audit_log_export_without_logs
    WebMock.allow_net_connect!
    HTTParty.stubs(:get).returns(HTTParty, true)
    HTTParty.stubs(:body).returns({ status: 200, data: { export_url: 'dummy_url' }.stringify_keys! }.to_json)
    AuditLogExport.any_instance.stubs(:export_csv).returns(true)
    AuditLogExport.any_instance.stubs(:upload_file).returns(true)
    AwsWrapper::S3Object.stubs(:store).returns(true)
    DataExportMailer.stubs(:audit_log_export).returns(true)
    args = construct_args_without_logs
    account = Account.first.nil? ? Account.first : create_test_account
    Account.stubs(:current).returns(Account.first)
    value = AuditLogExport.new.perform(args)
    WebMock.disable_net_connect!
  ensure
    WebMock.disable_net_connect!
    Export::Util.unstub(:build_attachment)
    Account.unstub(:current)
    User.unstub(:current)
  end

  def test_audit_log_export_with_invalid_user_id
    WebMock.allow_net_connect!
    args = construct_args_with_invalid_user_id
    account = Account.first.nil? ? Account.first : create_test_account
    Account.stubs(:current).returns(Account.first)
    value = AuditLogExport.new.perform(args)
    @data_export = @account.data_exports.last
    assert_equal @data_export.source, DataExport::EXPORT_TYPE[:audit_log]
    @data_export.destroy
    WebMock.disable_net_connect!
  ensure
    WebMock.disable_net_connect!
    Export::Util.unstub(:build_attachment)
    Account.unstub(:current)
    User.unstub(:current)
  end

  def test_audit_log_export_with_invalid_time
    WebMock.allow_net_connect!
    args = construct_args_with_invalid_time
    account = Account.first.nil? ? Account.first : create_test_account
    Account.stubs(:current).returns(Account.first)
    value = AuditLogExport.new.perform(args)
    @data_export = @account.data_exports.last
    assert_equal @data_export.status, DataExport::EXPORT_STATUS[:failed]
    assert_equal @data_export.source, DataExport::EXPORT_TYPE[:audit_log]
    @data_export.destroy
    WebMock.disable_net_connect!
  ensure
    WebMock.disable_net_connect!
    Export::Util.unstub(:build_attachment)
    Account.unstub(:current)
    User.unstub(:current)
  end

  private

    def construct_args_with_logs
      {
        export_job_id: '697bc4f0-be01-4db1-a6d3-4cf188b6d90d',
        time: 0,
        account_id: 1,
        user_id: 1,
        receive_via: 'api'
      }
    end

    def construct_args_without_logs
      {
        export_job_id: 'd2c45f4f-03ec-4e9d-aebf-92ac86b12ab6',
        time: 0,
        account_id: 1,
        user_id: 1,
        receive_via: 'email'
      }
    end

    def construct_args_with_invalid_user_id
      {
        export_job_id: 'd2c45f4f-03ec-4e9d-aebf-92ac86b12ab6',
        time: 0,
        account_id: 1,
        user_id: 100_001,
        receive_via: 'api'
      }
    end

    def construct_args_with_invalid_time
      {
        export_job_id: 'd2c45f4f-03ec-4e9d-aebf-92ac86b12ab6',
        time: 25,
        account_id: 1,
        user_id: 1,
        receive_via: 'email'
      }
    end
end
