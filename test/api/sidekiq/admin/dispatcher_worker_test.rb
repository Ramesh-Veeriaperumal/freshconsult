require_relative '../../../test_transactions_fixtures_helper'
require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'automation_rules_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'shared_ownership_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')

class Admin::Dispatcher::WorkerTest < ActionView::TestCase

  include AutomationRulesTestHelper
  include TicketsTestHelper
  include UsersTestHelper
  include SharedOwnershipTestHelper
  include TicketFieldsTestHelper

  CUSTOM_FIELD_TYPES = [:checkbox, :number, :decimal, :nestedlist, :date]

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  FIELD_OPERATOR_MAPPING.each do |operator_type, options|
    options[:fields].each do |field_name|
      options[:operators].each do |operator|
        define_method "test_dispatcher_condition_#{field_name}_#{operator}" do
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
          rule.save
          ticket_value = generate_value(operator_type, field_name, false) if ["greater_than", "less_than"].include?(operator)
          ticket_value = not_operator ? generate_value(operator_type, field_name, true) : rule_value unless ticket_value
          ticket_params = generate_ticket_params(field_name, ticket_value)
          ticket = Sidekiq::Testing.inline! { create_ticket(ticket_params.symbolize_keys) }
          ticket = ticket.reload
          assert_equal ticket.group_id, 4
        end
      end
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
    when 'created_at'
      ticket_value = Time.zone.today + 23.hours
    when 'internal_agent_id'
      internal_group = ticket_value ? @account.technicians.find_by_id(ticket_value).groups.first : nil
      status = internal_group.status_groups.first.status.status_id if internal_group.present?
      return {internal_agent_id: ticket_value, 
              internal_group_id: internal_group.try(:id),
              status: status}
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
      else
        not_operator ? 1 : 2
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
