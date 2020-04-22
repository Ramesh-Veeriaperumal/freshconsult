require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class CRECentralWorkerTest < ActionView::TestCase
  include ::AccountTestHelper
  include Admin::AutomationConstants
  include CentralPublish::CRECentralUtil

  def setup
    super
    @account = Account.first || create_new_account
    Account.any_instance.stubs(:current).returns(@account)
    @account.make_current
  end

  def teardown
    Account.any_instance.stubs(:current)
  end

  def create_rule(rule_type)
    va_rule = FactoryGirl.build(:va_rule,
      name: "created by #{Faker::Name.name}",
      description: Faker::Lorem.sentence(2),
      action_data: [
        {
          name: 'priority',
          value: '3'
        }
      ],
      filter_data: {
        events: [
          {
            name: 'priority',
            from: '--',
            to: '--'
          }
        ],
        performer: {
          'type' => '1'
        },
        conditions: [
          {
            name: 'ticket_type',
            operator: 'in',
            value: ['Problem', 'Question']
          }
        ]
      })
    va_rule.rule_type = rule_type
    va_rule.account_id = @account.id
    va_rule.save(validate: false)
    va_rule
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

  def test_webhook_error_event_payload
    va_rule = create_rule(VAConfig::OBSERVER_RULE)
    args = construct_args(va_rule)
    publish_payload = construct_webhook_error_payload(args)
    assert_equal true, match_webhook_error_payload(publish_payload, args, va_rule)
  end

  def test_webhook_error_event_payload_without_rule_id
    args = construct_args_without_rule_id
    publish_payload = construct_webhook_error_payload(args)
    assert_equal true, match_webhook_error_payload(publish_payload, args, nil)
  end

  def match_webhook_error_payload(publish_payload, args, va_rule)
    publish_payload == {
      payload_type: CRE_PAYLOAD_TYPES[:webhook_error],
      account_id: Account.current.id.to_s,
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
end
