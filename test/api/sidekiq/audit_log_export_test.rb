require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require 'webmock/minitest'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class AuditLogExportTest < ActiveSupport::TestCase
  include AccountTestHelper
  def setup
    @account = Account.first.present? ? Account.first.make_current : create_test_account
    @account.data_exports.destroy_all
    agent = @account.users.where(helpdesk_agent: true).first
    User.stubs(:current).returns(agent)
  end

  def test_audit_log_export_with_logs_csv
    WebMock.allow_net_connect!
    HTTParty.stubs(:get).returns(HTTParty, true)
    HTTParty.stubs(:body).returns({ status: 200, data: { export_url: 'dummy_url' }.stringify_keys! }.to_json)
    AuditLogExport.any_instance.stubs(:format_file_data).returns(true)
    AwsWrapper::S3Object.stubs(:store).returns(true)
    DataExportMailer.stubs(:audit_log_export).returns(true)
    args = construct_args_with_logs_csv
    write_json_to_file(construct_args_with_logs_csv[:export_job_id])
    value = AuditLogExport.new.perform(args)
    @data_export = @account.data_exports.last
    puts("test_audit_log_export_with_logs_csv: #{@data_export.last_error}")
    assert_equal @data_export.source, DataExport::EXPORT_TYPE[:audit_log]
    assert_equal @data_export.status, DataExport::EXPORT_STATUS[:completed]
    WebMock.disable_net_connect!
    @account.data_exports.destroy_all
  ensure
    Export::Util.unstub(:build_attachment)
    AwsWrapper::S3Object.unstub(:store)
    Account.reset_current_account
    User.reset_current_user
    remove_file_path(construct_args_with_logs_csv[:export_job_id])
  end

  def test_audit_log_export_with_logs_xls
    WebMock.allow_net_connect!
    HTTParty.stubs(:get).returns(HTTParty, true)
    HTTParty.stubs(:body).returns({ status: 200, data: { export_url: 'dummy_url' }.stringify_keys! }.to_json)
    AuditLogExport.any_instance.stubs(:format_file_data).returns(true)
    AwsWrapper::S3Object.stubs(:store).returns(true)
    DataExportMailer.stubs(:audit_log_export).returns(true)
    args = construct_args_with_logs_xls
    write_json_to_file(construct_args_with_logs_xls[:export_job_id])
    value = AuditLogExport.new.perform(args)
    @data_export = @account.data_exports.last
    puts("test_audit_log_export_with_logs_xls: #{@data_export.last_error}")
    assert_equal @data_export.source, DataExport::EXPORT_TYPE[:audit_log]
    assert_equal @data_export.status, DataExport::EXPORT_STATUS[:completed]
    WebMock.disable_net_connect!
    @account.data_exports.destroy_all
  ensure
    Export::Util.unstub(:build_attachment)
    AwsWrapper::S3Object.unstub(:store)
    WebMock.disable_net_connect!
    Account.reset_current_account
    User.reset_current_user
    remove_file_path(construct_args_with_logs_xls[:export_job_id])
  end

  def test_audit_log_export_without_logs
    WebMock.allow_net_connect!
    HTTParty.stubs(:get).returns(HTTParty, true)
    HTTParty.stubs(:body).returns({ status: 200, data: { export_url: 'dummy_url' }.stringify_keys! }.to_json)
    AuditLogExport.any_instance.stubs(:format_file_data).returns(true)
    AwsWrapper::S3Object.stubs(:store).returns(true)
    DataExportMailer.stubs(:audit_log_export).returns(true)
    args = construct_args_without_logs
    write_empty_file(construct_args_without_logs[:export_job_id])
    value = AuditLogExport.new.perform(args)
    @data_export = @account.data_exports.last
    puts("test_audit_log_export_without_logs: #{@data_export.last_error}")
    assert_equal @data_export.source, DataExport::EXPORT_TYPE[:audit_log]
    assert_equal @data_export.status, DataExport::EXPORT_STATUS[:no_logs]
    WebMock.disable_net_connect!
    @account.data_exports.destroy_all
  ensure
    WebMock.disable_net_connect!
    Export::Util.unstub(:build_attachment)
    AwsWrapper::S3Object.unstub(:store)
    Account.reset_current_account
    User.reset_current_user
    remove_file_path(construct_args_without_logs[:export_job_id])
  end

  def test_audit_log_export_with_invalid_time
    WebMock.allow_net_connect!
    args = construct_args_with_invalid_time
    value = AuditLogExport.new.perform(args)
    @data_export = @account.data_exports.last
    puts("test_audit_log_export_without_logs: #{@data_export.last_error}")
    assert_equal @data_export.status, DataExport::EXPORT_STATUS[:failed]
    assert_equal @data_export.source, DataExport::EXPORT_TYPE[:audit_log]
    WebMock.disable_net_connect!
    @account.data_exports.destroy_all
  ensure
    WebMock.disable_net_connect!
    Export::Util.unstub(:build_attachment)
    AwsWrapper::S3Object.unstub(:store)
    Account.reset_current_account
    User.reset_current_user
  end

  private

    def construct_args_with_logs_csv
      {
        export_job_id: '697bc4f0-be01-4db1-a6d3-4cf188b6d90d',
        time: 0,
        account_id: 1,
        user_id: 1,
        receive_via: 'email',
        archived: false,
        format: 'csv'
      }
    end

    def construct_args_with_logs_xls
      {
        export_job_id: 'a49eb52d-6573-44fe-8071-f4aa5c4d8a48',
        time: 0,
        account_id: 1,
        user_id: 1,
        receive_via: 'email',
        archived: true,
        format: 'xls'
      }
    end

    def construct_args_without_logs
      {
        export_job_id: 'd2c45f4f-03ec-4e9d-aebf-92ac86b12ab6',
        time: 0,
        account_id: 1,
        user_id: 1,
        receive_via: 'email',
        archived: false,
        format: 'xls'
      }
    end

    def construct_args_with_invalid_time
      {
        export_job_id: '3db8ddf3-9517-49c0-b6b5-7b00866b3fb5',
        time: 25,
        account_id: 1,
        user_id: 1,
        receive_via: 'email',
        archived: false,
        format: 'xls'
      }
    end

    def file_content
      {"actor":{"name":"freshdesk.1","id":71,"type":"agent"},"timestamp":1548922289641,"changes":{"filter_data":[[{"evaluate_on":"ticket","name":"subject","operator":"is","value":"test"}],[{"evaluate_on":"ticket","name":"subject","operator":"is","value":"test"}]],"action_data":[[{"name":"priority","value":"1"},{"name":"trigger_webhook","request_type":"1","url":"asd{{ticket.agent.name}}{{ticket.latest_public_comment}}{{ticket.requester.address}}{{helpdesk_name}}","custom_headers":""}],[{"name":"priority","value":"3"},{"name":"trigger_webhook","request_type":"1","url":"asd{{ticket.agent.name}}{{ticket.latest_public_comment}}{{ticket.requester.address}}{{helpdesk_name}}","custom_headers":""},{"name":"responder_id","value":"469"}]],"updated_at":["2019-01-28T19:12:31+05:30","2019-01-31T13:41:29+05:30"]},"object":{"name":"sadasds","description":"","rule_type":1,"id":1220,"account_id":1,"filter_data":[{"evaluate_on":"ticket","name":"subject","operator":"is","value":"test"}],"condition_data":{"all":[{"evaluate_on":"ticket","name":"subject","operator":"is","value":"test"}]},"position":1,"created_at":"2018-11-05T11:32:44Z","updated_at":"2019-01-31T08:11:29Z","match_type":"all","action_data":[{"name":"priority","value":"3"},{"name":"trigger_webhook","request_type":"1","url":"asd{{ticket.agent.name}}{{ticket.latest_public_comment}}{{ticket.requester.address}}{{helpdesk_name}}","custom_headers":""},{"name":"responder_id","value":"469"}],"active":true},"account_id":"1","ip_address":"182.73.13.166","action":"dispatcher_update"}
    end

    def write_json_to_file(job_id)
      file_path = Rails.root.join('tmp', "#{job_id}.json")
      File.open(file_path, 'w') do |file|
        file.write(file_content.to_json)
      end
    end

    def write_empty_file(job_id)
      file_path = Rails.root.join('tmp', "#{job_id}.json")
      File.open(file_path, 'w') do |file|
        file.write('')
      end
    end

    def remove_file_path(job_id)
      FileUtils.rm_rf(Rails.root.join('tmp', "#{job_id}.json"))
    end
end
