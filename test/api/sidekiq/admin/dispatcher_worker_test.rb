require_relative '../../../test_transactions_fixtures_helper'
require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'automation_rules_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'shared_ownership_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'agent_test_helper.rb')

class Admin::Dispatcher::WorkerTest < ActionView::TestCase

  include AutomationRulesTestHelper
  include CoreTicketsTestHelper
  include CoreUsersTestHelper
  include SharedOwnershipTestHelper
  include TicketFieldsTestHelper
  include AgentTestHelper

  CUSTOM_FIELD_TYPES = [:checkbox, :number, :decimal, :nested_field, :date]

  def setup
    create_test_account if Account.first.nil?
    Account.stubs(:current).returns(Account.first)
    @account = Account.first
  end

  def teardown
    Account.unstub(:current)
    super
  end

  FIELD_OPERATOR_MAPPING.each do |operator_type, options|
    options[:fields].each do |field_name|
      options[:operators].each do |operator|
        define_method "test_dispatcher_condition_#{field_name}_#{operator}" do
          Rails.logger.debug "start test_dispatcher_condition_#{field_name}_#{operator}"
          Account.current.launch :automation_revamp
          Account.current.add_feature :shared_ownership
          initialize_internal_agent_with_default_internal_group
          if CUSTOM_FIELD_TYPES.include?(operator_type)
            field = @account.ticket_fields.find_by_field_type("custom_#{operator_type.to_s}")
            unless field
              field = operator_type == :nested_field ?
                        create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city)) :
                        create_custom_field(Faker::Lorem.characters(9), operator_type.to_s)
            end
            field_name = field.name
          end

          not_operator = operator.include?('not')
          rule_value = generate_value(operator_type, field_name, false, operator)
          rule = Account.current.va_rules.first
          condition_data = { all: [ 
            { evaluate_on: "ticket", 
              name: field_name, 
              operator: operator, 
              value: rule_value}]
          }
          if operator_type == :nested_field && operator == "is"
            nested_rules = []
            field.child_levels.each do |child_field|
              nested_rules << {
                name: child_field.name,
                value: generate_value(operator_type, child_field.name, false, operator),
                operator: operator
              }
            end
            condition_data[:all].first.merge!({ nested_rules: nested_rules })
          end
          rule.condition_data = condition_data
          group = Account.current.groups.first || create_group(Account.current)
          rule.action_data = options[:actions].map do |action|
            generate_action_data(action, not_operator)
          end
          rule.save
          ticket_value = generate_value(operator_type, field_name, false) if ["greater_than", "less_than"].include?(operator)
          ticket_value = not_operator ? generate_value(operator_type, field_name, true) : rule_value unless ticket_value
          ticket_value = ticket_value.first if ticket_value.is_a?(Array) && operator == 'is_any_of'
          ticket_params = generate_ticket_params(field_name, ticket_value)
          ticket = Sidekiq::Testing.inline! { create_ticket(ticket_params.symbolize_keys) }
          ticket = ticket.reload
          rule.action_data.each do |action|
            verify_action_data(action, ticket, not_operator)
          end
          Rails.logger.debug "end test_dispatcher_condition_#{field_name}_#{operator}"
        end
      end
    end
  end

  def test_dispatcher_condition_responder_id_is_any
    Rails.logger.debug "start test_dispatcher_condition_responder_id_is_any"
    Account.current.launch :automation_revamp
    Account.current.add_feature :shared_ownership
    initialize_internal_agent_with_default_internal_group
    rule = Account.current.va_rules.first
    rule.condition_data = { all: [ 
      { evaluate_on: "ticket", 
        name: "responder_id", 
        operator: "is", 
        value: -1}]
    }
    group = Account.current.groups.first || create_group(Account.current)
    rule.action_data = ["priority"].map do |action|
      generate_action_data(action, false)
    end

    rule.save
    ticket_value =  generate_value(:object_id, "responder_id", false)
    ticket_params = generate_ticket_params("responder_id", ticket_value)
    ticket = Sidekiq::Testing.inline! { create_ticket(ticket_params.symbolize_keys) }
    ticket = ticket.reload
    rule.action_data.each do |action|
      verify_action_data(action, ticket, false)
    end
    Rails.logger.debug "end test_dispatcher_condition_responder_id_is_any"
  end
  
  def test_dispatcher_condition_subject_or_description_is_any_of_case_sensitive_false
    Account.current.launch :automation_revamp
    rule = Account.current.va_rules.first
    rule.condition_data = { any: [
      { evaluate_on: "ticket", 
        name: "subject_or_description", 
        operator: "is_any_of", 
        value: ["Test"], 
        case_sensitive: false}]
    }

    rule.action_data = [{ name: 'priority', value: 2 }]
    rule.save
    ticket_params = generate_ticket_params("subject_or_description", "test sample")
    ticket = Sidekiq::Testing.inline! { create_ticket(ticket_params.symbolize_keys) }
    ticket = ticket.reload
    rule.action_data.each do |action|
      verify_action_data(action, ticket, false)
    end
  ensure
    Account.current.rollback :automation_revamp
  end
  
  def test_dispatcher_condition_subject_or_description_is_any_of_case_sensitive_true
    Account.current.launch :automation_revamp
    rule = Account.current.va_rules.first
    rule.condition_data = { any: [
      { evaluate_on: "ticket", 
        name: "subject_or_description", 
        operator: "is_any_of", 
        value: ["Test"], 
        case_sensitive: true}]
    }
    
    rule.action_data = ["priority"].map do |action|
      generate_action_data(action, true)
    end
    rule.save
    ticket_params = generate_ticket_params("subject_or_description", "test sample")
    ticket = Sidekiq::Testing.inline! { create_ticket(ticket_params.symbolize_keys) }
    ticket = ticket.reload
    rule.action_data = [{name: "priority", value: 2}]
    rule.action_data.each do |action|
      verify_action_data(action, ticket, false)
    end
  ensure
    Account.current.rollback :automation_revamp
  end

  def test_dispatcher_condition_responder_is_unavailable
    Rails.logger.debug "start test_dispatcher_condition_responder_id_is_any"
    Account.current.launch :automation_revamp
    Account.current.add_feature :shared_ownership
    initialize_internal_agent_with_default_internal_group
    rule = Account.current.va_rules.first
    rule.condition_data = { all: [ 
      { evaluate_on: "ticket", 
        name: "responder_id", 
        operator: "is", 
        value: -1,
        related_conditions: {
          name: "availability_status",
          operator: "is",
          value: "unavailable"
        }
      }
      ]
    }
    group = Account.current.groups.first || create_group(Account.current)
    rule.action_data = ["priority"].map do |action|
      generate_action_data(action, false)
    end

    rule.save
    ticket_value =  generate_value(:object_id, "responder_id", false)
    ticket_params = generate_ticket_params("responder_id", ticket_value)
    agent = Account.current.agents.find_by_user_id(ticket_params[:responder_id])
    agent.available = false
    agent.save
    
    ticket = Sidekiq::Testing.inline! { create_ticket(ticket_params.symbolize_keys) }
    ticket = ticket.reload
    rule.action_data.each do |action|
      verify_action_data(action, ticket, false)
    end
    Rails.logger.debug "end test_dispatcher_condition_responder_id_is_any"
  end

  def test_dispatcher_condition_any_responder_greater_than_ooo
    Rails.logger.debug 'start test_dispatcher_condition_any_responder_greater_than_ooo'
    Account.current.launch :automation_revamp
    Account.current.launch :out_of_office
    initialize_internal_agent_with_default_internal_group
    rule = Account.current.va_rules.first
    rule.condition_data = ooo_condition_data('greater_than', 1)
    group = Account.current.groups.first || create_group(Account.current)
    rule.action_data = ['priority'].map do |action|
      generate_action_data(action, false)
    end

    rule.save
    ticket_value =  generate_value(:object_id, 'responder_id', false)
    ticket_params = generate_ticket_params('responder_id', ticket_value)
    agent = Account.current.agents.find_by_user_id(ticket_params[:responder_id])
    agent.save

    ticket = Sidekiq::Testing.inline! { create_ticket(ticket_params.symbolize_keys) }
    ticket = ticket.reload
    rule.action_data.each do |action|
      verify_action_data(action, ticket, false)
    end
    Rails.logger.debug 'start test_dispatcher_condition_any_responder_greater_than_ooo'
  ensure
    Account.current.rollback :out_of_office
    Account.current.rollback :automation_revamp
    Account.unstub(:current)
  end

  def test_dispatcher_condition_any_responder_less_than_ooo
    Rails.logger.debug 'start test_dispatcher_condition_any_responder_less_than_ooo'
    Account.current.launch :automation_revamp
    Account.current.launch :out_of_office
    initialize_internal_agent_with_default_internal_group
    rule = Account.current.va_rules.first
    rule.condition_data = ooo_condition_data('less_than', 10)
    group = Account.current.groups.first || create_group(Account.current)
    rule.action_data = ['priority'].map do |action|
      generate_action_data(action, false)
    end

    rule.save
    ticket_value =  generate_value(:object_id, 'responder_id', false)
    ticket_params = generate_ticket_params('responder_id', ticket_value)
    agent = Account.current.agents.find_by_user_id(ticket_params[:responder_id])
    agent.save

    ticket = Sidekiq::Testing.inline! { create_ticket(ticket_params.symbolize_keys) }
    ticket = ticket.reload
    rule.action_data.each do |action|
      verify_action_data(action, ticket, false)
    end
    Rails.logger.debug 'end test_dispatcher_condition_any_responder_less_than_ooo'
  ensure
    Account.current.rollback :out_of_office
    Account.current.rollback :automation_revamp
    Account.unstub(:current)
  end

  def test_dispatcher_condition_any_responder_equals_ooo
    Rails.logger.debug 'start test_dispatcher_condition_any_responder_equals_ooo'
    Account.current.launch :automation_revamp
    Account.current.launch :out_of_office
    initialize_internal_agent_with_default_internal_group
    rule = Account.current.va_rules.first
    rule.condition_data = ooo_condition_data('is', 5)
    group = Account.current.groups.first || create_group(Account.current)
    rule.action_data = ['priority'].map do |action|
      generate_action_data(action, false)
    end

    rule.save
    ticket_value =  generate_value(:object_id, 'responder_id', false)
    ticket_params = generate_ticket_params('responder_id', ticket_value)
    agent = Account.current.agents.find_by_user_id(ticket_params[:responder_id])
    agent.save

    ticket = Sidekiq::Testing.inline! { create_ticket(ticket_params.symbolize_keys) }
    ticket = ticket.reload
    rule.action_data.each do |action|
      verify_action_data(action, ticket, false)
    end
    Rails.logger.debug 'end test_dispatcher_condition_any_responder_equals_ooo'
  ensure
    Account.current.rollback :out_of_office
    Account.current.rollback :automation_revamp
    Account.unstub(:current)
  end

  def test_dispatcher_failed_condition_any_responder_is_ooo
    Rails.logger.debug 'start test_dispatcher_failed_condition_any_responder_is_ooo'
    Account.current.launch :automation_revamp
    rule = Account.current.va_rules.first
    rule.condition_data = ooo_condition_data('greater_than', 10)
    rule.action_data = [{ name: 'priority', value: 1 }]

    rule.save
    ticket_params = generate_ticket_params('subject_or_description', 'test_for_ooo')
    ticket = Sidekiq::Testing.inline! { create_ticket(ticket_params.symbolize_keys) }
    ticket = ticket.reload
    rule.action_data.each do |action|
      verify_failed_action_data(action, ticket, false)
    end
    Rails.logger.debug 'end test_dispatcher_failed_condition_any_responder_is_ooo'
  ensure
    Account.current.rollback :automation_revamp
    Account.unstub(:current)
  end

  def verify_failed_action_data(action, ticket, _not_operator)
    case true
    when ['priority', 'ticket_type', 'status', 'responder_id', 'product_id', 'group_id'].include?(action[:name])
      assert_not_equal ticket.safe_send(action[:name]), action[:value]
    end
  end

  def ooo_condition_data(op_value, days_value)
    { all: [
      { evaluate_on: 'ticket',
        name: 'responder_id',
        operator: 'in',
        value: -1,
        related_conditions: [{
          name: 'availability_status',
          operator: 'is',
          value: 'out_of_office',
          related_conditions: [{
            name: 'out_of_office',
            operator: op_value,
            value: days_value
          }]
        }] }
    ] }
  end
end
