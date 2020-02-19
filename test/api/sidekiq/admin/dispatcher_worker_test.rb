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

class Admin::Dispatcher::WorkerTest < ActionView::TestCase

  include AutomationRulesTestHelper
  include CoreTicketsTestHelper
  include CoreUsersTestHelper
  include SharedOwnershipTestHelper
  include TicketFieldsTestHelper

  CUSTOM_FIELD_TYPES = [:checkbox, :number, :decimal, :nestedlist, :date]

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
            field = create_custom_field(Faker::Lorem.characters(9), operator_type.to_s) unless field
            field_name = field.name
          end

          not_operator = operator.include?('not')
          rule_value = generate_value(operator_type, field_name, false, operator)
          rule = Account.current.va_rules.first
          rule.condition_data = { all: [ 
            { evaluate_on: "ticket", 
              name: field_name, 
              operator: operator, 
              value: rule_value}]
          }
          group = Account.current.groups.first || create_group(Account.current)
          rule.action_data = options[:actions].map do |action|
            generate_action_data(action, not_operator)
          end
          rule.save
          ticket_value = generate_value(operator_type, field_name, false) if ["greater_than", "less_than"].include?(operator)
          ticket_value = not_operator ? generate_value(operator_type, field_name, true) : rule_value unless ticket_value
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
    
    rule.action_data = ["priority"].map do |action|
      generate_action_data(action, true)
    end

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
        relater_conditions: {
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

  def verify_action_data(action, ticket, not_operator)
    case true
    when ['priority', 'ticket_type', 'status', 'responder_id', 'product_id', 'group_id'].include?(action[:name])
      assert_equal ticket.safe_send(action[:name]), action[:value]
    end
  end

  def generate_action_data(action, not_operator)
    case true
    when ['responder_id', 'group_id'].include?(action)
      {
        name: action,
        value: generate_value(:object_id, action, not_operator)
      }
    when ['priority', 'ticket_type', 'status', 'product_id'].include?(action)
      {
        name: action,
        value: generate_value(:choicelist, action, not_operator)
      }
    end
  end

  def generate_ticket_params(field_name, ticket_value)
    params = case field_name
    when 'from_email'
      user = add_new_user(Account.current, { email: ticket_value})
      return {sender_email: ticket_value, requester_id: user.id}
    when 'ticlet_cc'
      field_name = 'cc_emails'
    when 'subject_or_description'
      field_name = 'subject'
    when 'created_during'
      field_name = 'created_at'
      ticket_value = Time.zone.today + 23.hours
    when 'internal_agent_id'
      internal_group = ticket_value ? @account.technicians.find_by_id(ticket_value).groups.first : nil
      status = internal_group.status_groups.first.status.status_id if internal_group.present?
      return {internal_agent_id: ticket_value, 
              internal_group_id: internal_group.try(:id),
              status: status}
    when 'to_email'
      field_name = 'to_emails'
    when 'internal_group_id'
      internal_group = ticket_value ? @account.groups.find_by_id(ticket_value) : nil
      status = internal_group.status_groups.first.status.status_id if internal_group.present?
      return {internal_group_id: internal_group.try(:id),
              status: status}
    end
    field_name.ends_with?("_#{@account.id}") ? {custom_field: { "#{field_name}": ticket_value }} : 
                                              { "#{field_name}": ticket_value }
  end

  def generate_value(operator_type, field_name, not_operator, operator=nil)
    case operator_type
    when :email
      Faker::Internet.email
    when :text
      Faker::Lorem.characters(10)
    when :choicelist
      case field_name
      when 'priority'
        not_operator ? 1 : 2
      when 'ticket_type'
        not_operator ? 'Question' : 'Incident'
      when 'status'
        not_operator ? 2 : 3
      when 'source'
        not_operator ? 1 : 2
      when 'product_id'
        @account.products.new(name: Faker::Name.name).save if @account.products.count == 0
        product = @account.products.first
        not_operator ? nil : product.id
      end
    when :date_time
      not_operator ? 'business_hours' : 'non_business_hours'
    when :object_id
      case field_name
      when 'internal_agent_id'
        group = @account.ticket_statuses.visible.where(is_default: false).first.status_groups.first.group
        agents = group.agents
        not_operator ? nil : agents.first.id
      when 'internal_group_id'
        group = @account.ticket_statuses.visible.where(is_default: false).first.status_groups.first.group
        not_operator ? nil : group.id
      when 'group_id'
        not_operator ? nil : Account.current.groups.first.id
      when 'responder_id'
        not_operator ? nil : Account.current.technicians.first.id
      end
    when :object_id_array
      @account.tags.new(name: Faker::Name.name).save if @account.tags.count == 0
      tag = @account.tags.first
      not_operator ? nil : [tag.id]
    when :checkbox
      not_operator ? false : true
    when :date
      return '2017-11-02' if not_operator
      case operator
      when 'greater_than'
        (Time.zone.now - 1.day).strftime('%Y-%m-%d')
      when 'less_than'
        (Time.zone.now + 1.day).strftime('%Y-%m-%d')
      else
        Time.zone.now.strftime('%Y-%m-%d')
      end
    when :number
      return 1 if not_operator
      case operator
      when 'greater_than'
        1
      when 'less_than'
        3
      else
        2
      end
    when :decimal
      return 1.0 if not_operator
      case operator
      when 'greater_than'
        1.0
      when 'less_than'
        3.0
      else
        2.0
      end
    end
  end
end
