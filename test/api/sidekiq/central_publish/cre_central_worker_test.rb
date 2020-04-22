require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'lib', 'helpers', 'va_rules_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class CRECentralWorkerTest < ActionView::TestCase
  include ::AccountTestHelper
  include VaRulesTesthelper
  include Admin::AutomationConstants
  include CentralPublish::CRECentralUtil

  def setup
    super
    @account = Account.first || create_new_account
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
      'error_type': WEBHOOK_ERROR_TYPES[:failure]
    }
  end

  def construct_args_without_rule_id
    {
      'ticket_id': 1,
      'account_id': @account.id,
      'error_type': WEBHOOK_ERROR_TYPES[:failure]
    }
  end

  def expected_payload(args, va_rule)
    {
      payload_type: CRE_PAYLOAD_TYPES[:webhook_error],
      account_id: @account.id.to_s,
      pod: PodConfig['CURRENT_POD'],
      region: PodConfig['CURRENT_REGION'],
      payload: {
        event_info: {
          pod: ChannelFrameworkConfig['pod']
        },
        data: {
          error_type: args.key?(:error_type) ? args[:error_type] : nil,
          rule_type: va_rule.present? ? va_rule.rule_type_desc.to_s : nil,
          reset_metric: args.key?(:reset_metric) ? args[:reset_metric] : nil,
          rule_id: args.key?(:rule_id) ? args[:rule_id] : nil
        },
        context: {
          ticket_id: args.key?(:ticket_id) ? args[:ticket_id] : nil
        }
      }
    }
  end

  def test_webhook_error_event_posted_to_central
    Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new(status: 202))
    va_rule = create_rule_with_type(VAConfig::OBSERVER_RULE, @account.id)
    args = construct_args(va_rule)
    response = CentralPublish::CRECentralWorker.new.perform(args, CRE_PAYLOAD_TYPES[:webhook_error])
    assert_equal 0, CentralPublish::CRECentralWorker.jobs.size
    assert_equal response[:status], 202
    assert_equal response[:data], expected_payload(args, va_rule)
  ensure
    Faraday::Connection.any_instance.unstub(:post)
  end

  def test_webhook_error_event_posted_to_central_without_rule_id
    Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new(status: 202))
    args = construct_args_without_rule_id
    response = CentralPublish::CRECentralWorker.new.perform(args, CRE_PAYLOAD_TYPES[:webhook_error])
    assert_equal 0, CentralPublish::CRECentralWorker.jobs.size
    assert_equal response[:status], 202
    assert_equal response[:data], expected_payload(args, nil)
  ensure
    Faraday::Connection.any_instance.unstub(:post)
  end
end
