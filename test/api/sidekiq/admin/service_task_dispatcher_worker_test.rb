require_relative '../../../test_transactions_fixtures_helper'
require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest'
Sidekiq::Testing.fake!

require Rails.root.join('spec', 'support', 'ticket_helper.rb')
require Rails.root.join('spec', 'support', 'user_helper.rb')
class Admin::ServiceTaskDispatcher::WorkerTest < ActionView::TestCase
  include TicketConstants
  include Admin::AdvancedTicketing::FieldServiceManagement::Util
  include TicketHelper
  include UsersHelper
  include AccountTestHelper

  FIELD_OPERATOR_MAPPING = {
    priority: ['in', 'not_in']
  }.freeze

  def setup
    create_test_account if Account.first.nil?
    Account.stubs(:current).returns(Account.first)
    @account = Account.first
    user = add_test_agent(Account.current)
    user.make_current
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    Account.current.all_service_task_dispatcher_rules.destroy_all
  end

  def teardown
    cleanup_fsm
    Account.current.all_service_task_dispatcher_rules.destroy_all
    Account.unstub(:current)
    super
  end

  def priority_condition_data_hash(priority_id, operator = FIELD_OPERATOR_MAPPING[:priority][0])
    { field_name: 'priority', operator: operator, value: priority_id }
  end

  def responder_action_data_hash
    { field_name: 'responder_id', value: User.current.id }
  end

  def create_dispatcher_rule(condition_data, action_data, is_service_task_rule = true)
    rule = is_service_task_rule ? Account.current.service_task_dispatcher_rules.new : Account.current.va_rules.new
    rule.name = Faker::Lorem.characters(10)
    rule.condition_data = {
      all: [{
               evaluate_on: 'ticket',
               name: condition_data[:field_name],
               operator: condition_data[:operator],
               value: condition_data[:value]
            }]
    }
    rule.action_data = [{
                           name: action_data[:field_name],
                           value: action_data[:value]
                        }]
    rule.save
  end

  def test_service_task_dispatcher_when_priority_is_high_set_status_to_pending
    perform_fsm_operations
    high_priority_id = TicketConstants::PRIORITY_KEYS_BY_TOKEN[:high]
    pending_status_id = Helpdesk::Ticketfields::TicketStatus::PENDING
    condition_data = priority_condition_data_hash(high_priority_id)
    action_data = { field_name: 'status', value: pending_status_id }
    create_dispatcher_rule(condition_data, action_data)
    service_task = Sidekiq::Testing.inline! { create_service_task_ticket(priority: high_priority_id) }
    assert_not_nil service_task
    service_task = service_task.reload
    assert_equal pending_status_id, service_task.status
  end

  def test_service_task_dispatcher_when_priority_is_high_set_responder_id
    perform_fsm_operations
    high_priority_id = TicketConstants::PRIORITY_KEYS_BY_TOKEN[:high]
    condition_data = priority_condition_data_hash(high_priority_id)
    action_data = responder_action_data_hash
    create_dispatcher_rule(condition_data, action_data)
    service_task = Sidekiq::Testing.inline! { create_service_task_ticket(priority: high_priority_id) }
    assert_not_nil service_task
    service_task = service_task.reload
    assert_equal User.current.id, service_task.responder_id
  end

  def test_service_task_dispatcher_when_priority_not_in_high_set_responder_id
    perform_fsm_operations
    condition_data = priority_condition_data_hash(TicketConstants::PRIORITY_KEYS_BY_TOKEN[:high],
                                                  FIELD_OPERATOR_MAPPING[:priority][1])
    action_data = responder_action_data_hash
    create_dispatcher_rule(condition_data, action_data)
    service_task = Sidekiq::Testing.inline! { create_service_task_ticket }
    assert_not_nil service_task
    service_task = service_task.reload
    assert_equal User.current.id, service_task.responder_id
  end

  def test_service_task_dispatcher_is_enqueued_on_service_task_create
    Admin::Dispatcher::Worker.jobs.clear
    Admin::ServiceTaskDispatcher::Worker.jobs.clear
    perform_fsm_operations
    condition_data = priority_condition_data_hash(TicketConstants::PRIORITY_KEYS_BY_TOKEN[:high])
    action_data = responder_action_data_hash
    create_dispatcher_rule(condition_data, action_data)
    create_service_task_ticket
    assert_equal 1, Admin::Dispatcher::Worker.jobs.size # Job will be enqueued for parent ticket
    assert_equal 1, Admin::ServiceTaskDispatcher::Worker.jobs.size
  ensure
    Admin::Dispatcher::Worker.jobs.clear
    Admin::ServiceTaskDispatcher::Worker.jobs.clear
  end

  def test_dispatcher_is_enqueued_on_ticket_create
    Admin::Dispatcher::Worker.jobs.clear
    Admin::ServiceTaskDispatcher::Worker.jobs.clear
    perform_fsm_operations
    condition_data = priority_condition_data_hash(TicketConstants::PRIORITY_KEYS_BY_TOKEN[:high])
    action_data = responder_action_data_hash
    create_dispatcher_rule(condition_data, action_data, false)
    create_ticket
    assert_equal 1, Admin::Dispatcher::Worker.jobs.size
    assert_equal 0, Admin::ServiceTaskDispatcher::Worker.jobs.size
  ensure
    Admin::Dispatcher::Worker.jobs.clear
    Admin::ServiceTaskDispatcher::Worker.jobs.clear
  end
end
