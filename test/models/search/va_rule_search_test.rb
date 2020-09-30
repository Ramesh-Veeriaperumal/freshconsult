require_relative '../test_helper'
require 'faker'
['va_rules_test_helper.rb'].each { |file| require Rails.root.join("test/lib/helpers/#{file}") }
['automation_delegator_test_helper.rb', 'ticket_fields_test_helper.rb'].each do |file|
  require Rails.root.join("test/api/helpers/#{file}")
end
['shared_ownership_test_helper.rb', 'company_fields_test_helper.rb'].each do |file|
  require Rails.root.join("test/core/helpers/#{file}")
end

class Search::VaRuleSearchTest < ActiveSupport::TestCase
  include VaRulesTesthelper
  include AutomationDelegatorTestHelper
  include TicketFieldsTestHelper
  include CompanyFieldsTestHelper
  include SharedOwnershipTestHelper

  @@before_all_run = false

  def setup
    super
    before_all
  end

  def before_all
    current_account.add_feature :shared_ownership
    Account.current.instance_variable_set('@ticket_fields_from_cache', nil)
    return if @@before_all_run
    current_account.ticket_fields.custom_fields.each(&:destroy)
    get_all_custom_fields
    create_products(current_account)
    create_tags_data(current_account)
    get_a_dropdown_custom_field_search
    get_a_nested_custom_field
    @account = Account.current || Account.first.make_current
    initialize_internal_agent_with_default_internal_group
    Account.current.instance_variable_set('@ticket_fields_from_cache', nil)
    @@before_all_run = true
  end

  def teardown
    current_account.remove_feature :shared_ownership
  end

  def test_dispatcher_search_condition_subject
    create_dispatcher_and_assert_conditions(:subject)
  end

  def test_dispatcher_search_condition_description
    create_dispatcher_and_assert_conditions(:description)
  end

  def test_dispatcher_search_condition_subject_or_description
    create_dispatcher_and_assert_conditions(:subject_or_description)
  end

  def test_dispatcher_search_condition_from_email
    create_dispatcher_and_assert_conditions(:from_email)
  end

  def test_dispatcher_search_condition_to_email
    create_dispatcher_and_assert_conditions(:to_email)
  end

  def test_dispatcher_search_condition_ticket_cc
    create_dispatcher_and_assert_conditions(:to_email)
  end

  def test_dispatcher_search_condition_product_id
    create_dispatcher_and_assert_conditions(:product_id)
  end

  def test_dispatcher_search_condition_group_id
    create_dispatcher_and_assert_conditions(:group_id)
  end

  def test_dispatcher_search_condition_responder_id
    create_dispatcher_and_assert_conditions(:responder_id)
  end

  def test_dispatcher_search_condition_internal_group_id
    create_dispatcher_and_assert_conditions(:internal_group_id)
  end

  def test_dispatcher_search_condition_internal_agent_id
    create_dispatcher_and_assert_conditions(:internal_agent_id)
  end

  def test_dispatcher_search_condition_status
    create_dispatcher_and_assert_conditions(:status)
  end

  def test_dispatcher_search_condition_priority
    create_dispatcher_and_assert_conditions(:priority)
  end

  def test_dispatcher_search_condition_source
    create_dispatcher_and_assert_conditions(:source)
  end

  def test_dispatcher_search_condition_cf_date
    create_dispatcher_and_assert_conditions(:cf_date)
  end

  def test_dispatcher_search_condition_cf_paragraph
    create_dispatcher_and_assert_conditions(:cf_paragraph)
  end

  def test_dispatcher_search_condition_cf_text
    create_dispatcher_and_assert_conditions(:cf_text)
  end

  def test_dispatcher_search_condition_cf_checkbox
    create_dispatcher_and_assert_conditions(:cf_checkbox)
  end

  def test_dispatcher_search_condition_cf_number
    create_dispatcher_and_assert_conditions(:cf_number)
  end

  def test_dispatcher_search_condition_cf_decimal
    create_dispatcher_and_assert_conditions(:cf_decimal)
  end

  def test_dispatcher_search_action_priority
    create_dispatcher_and_assert_actions(:priority)
  end

  def test_dispatcher_search_action_status
    create_dispatcher_and_assert_actions(:status)
  end

  def test_dispatcher_search_action_responder_id
    create_dispatcher_and_assert_actions(:responder_id)
  end

  def test_dispatcher_search_action_group_id
    create_dispatcher_and_assert_actions(:group_id)
  end

  def test_dispatcher_search_action_internal_agent_id
    create_dispatcher_and_assert_actions(:internal_agent_id)
  end

  def test_dispatcher_search_action_product_id
    create_dispatcher_and_assert_actions(:product_id)
  end

  def test_dispatcher_search_action_internal_group_id
    create_dispatcher_and_assert_actions(:internal_group_id)
  end

  def test_dispatcher_search_action_add_a_cc
    create_dispatcher_and_assert_actions(:add_a_cc)
  end

  def test_observer_search_events_priority
    create_dispatcher_and_assert_actions(:priority)
  end

  def test_observer_search_events_status
    create_dispatcher_and_assert_actions(:status)
  end

  def test_observer_search_events_responder_id
    create_dispatcher_and_assert_actions(:responder_id)
  end

  def test_observer_search_events_group_id
    create_dispatcher_and_assert_actions(:group_id)
  end

  def test_dispatcher_search_action_group_id_array
    field_name = :group_id
    field_type = FIELD_TO_TYPE_MAPPING[field_name]
    conditions = generate_condition(field_type, field_name, true)

    va_rule = create_rule(VAConfig::BUSINESS_RULE)
    va_rule.condition_data = { all: conditions }
    va_rule.save
    expected_transformed_conditions = transform_conditions(field_type, conditions)
    actual_pattern = JSON.parse(va_rule.to_esv2_json)
    assert_equal(expected_transformed_conditions, actual_pattern['conditions'])
  ensure
    current_account.va_rules.find(va_rule.id).try(:destroy)
  end

  private

    def create_dispatcher_and_assert_conditions(field_name)
      field_type = FIELD_TO_TYPE_MAPPING[field_name]
      conditions = generate_condition(field_type, field_name)

      va_rule = create_rule(VAConfig::BUSINESS_RULE)
      va_rule.condition_data = { all: conditions }
      va_rule.save

      expected_transformed_conditions = transform_conditions(field_type, conditions)
      actual_pattern = JSON.parse(va_rule.to_esv2_json)
      assert_equal(expected_transformed_conditions, actual_pattern['conditions'])
    ensure
      current_account.va_rules.find(va_rule.id).try(:destroy)
    end

    def create_dispatcher_and_assert_actions(field_name)
      conditions = generate_condition(FIELD_TO_TYPE_MAPPING[:subject], :subject)
      field_type = FIELD_TO_TYPE_MAPPING[field_name]
      actions = generate_actions(field_type, field_name)
      va_rule = create_rule(VAConfig::BUSINESS_RULE)
      va_rule.condition_data = { all: conditions }
      va_rule .action_data = actions
      va_rule.save

      expected_transformed_actions = transform_actions(field_type, actions)
      actual_pattern = JSON.parse(va_rule.to_esv2_json)
      assert_equal(expected_transformed_actions, actual_pattern['actions'])
    ensure
      current_account.va_rules.find(va_rule.id).try(:destroy)
    end

    def create_observer_and_assert_events(field_name)
      conditions = generate_condition(FIELD_TO_TYPE_MAPPING[:subject], :subject)
      actions = generate_actions(FIELD_TO_TYPE_MAPPING[:priority], :priority)

      field_type = FIELD_TO_TYPE_MAPPING[field_name]
      events = generate_events(field_type, field_name)
      va_rule = create_rule(VAConfig::OBSERVER_RULE)
      va_rule.condition_data = { events: events,
                                 performer: { type: 1 },
                                 conditions: { all: conditions } }
      va_rule .action_data = actions
      va_rule.save

      expected_transformed_events = transform_events(field_type, events)
      actual_pattern = JSON.parse(va_rule.to_esv2_json)
      assert_equal(expected_transformed_events, actual_pattern['events'])
    ensure
      current_account.va_rules.find(va_rule.id).try(:destroy)
    end

    def create_rule(rule_type)
      va_rule = FactoryGirl.build(:va_rule, name: Faker::Name.name)
      va_rule.rule_type = rule_type
      va_rule.account_id = current_account.id
      va_rule
    end

    def generate_condition(field_type, field_name, multiple_values = false)
      TYPE_TO_OPERATOR_MAPPING[field_type].map do |operator|
        array_operator = ARRAY_VALUE_OPERATORS.include?(operator)
        value = generate_mock_value(field_type, field_name, (multiple_values && array_operator))
        condition = {
          evaluate_on: 'ticket',
          name: transform_name(field_name),
          operator: operator
        }
        if value.present?
          value = transform_value(value, :array) if array_operator
          condition[:value] = value
        end
        condition
      end
    end

    def generate_actions(field_type, field_name)
      value = generate_mock_value(field_type, field_name)
      action = { name: transform_name(field_name) }
      action[:value] = value if value.present?
      [action]
    end

    def generate_events(field_type, field_name)
      value = generate_mock_value(field_type, field_name)
      event = { name: transform_name(field_name) }
      if value.present?
        event[:from] = value
        event[:to] = value
      end
      [event]
    end

    def va_rules_search_pattern(rule)
      {
        id: rule.id,
        account_id: Account.current.id,
        name: rule.name,
        created_at: rule.created_at,
        updated_at: rule.updated_at,
        rule_type: rule.rule_type,
        active: rule.active,
        outdated: rule.outdated,
        updated_by: rule.last_updated_by,
        performer: [],
        events: [],
        conditions: [],
        actions: []
      }.to_json
    end

    def transform_actions(_field_type, actions)
      actions.map do |action|
        action.symbolize_keys!
        action[:value].present? ? "#{action[:name]}:#{action[:value]}" : action[:name].to_s
      end
    end

    def transform_events(_field_type, events)
      events.map do |event|
        event.symbolize_keys!
        "#{event[:name]}:#{event[:from]}:#{event[:to]}"
      end
    end

    def transform_conditions(_field_type, conditions)
      trans_conditions = []
      conditions.each do |condition|
        condition.symbolize_keys!
        name = transform_name_for_search(condition[:name])
        value = condition[:value]
        if [:subject, :description, :subject_or_description, :cf_paragraph, :cf_text].include?(name.try(:to_sym))
          trans_conditions << "#{EVALUATE_ON_MAPPING[condition[:evaluate_on].to_sym]}:#{transform_name_for_search(condition[:name])}:present"
        else
          search_value = "#{condition[:evaluate_on]}:#{name}:#{condition[:operator]}"
          if value.is_a?(Array)
            value.each { |v| trans_conditions << "#{search_value}:#{v}" }
          else
            trans_conditions << (value.present? ? "#{search_value}:#{value}" : search_value)
          end
        end
      end
      trans_conditions
    end

    def get_a_dropdown_custom_field_search
      @account = Account.current || Account.first.make_current
      create_custom_field_dropdown("test_custom_dropdown_search")
      @account = nil
    end
end
