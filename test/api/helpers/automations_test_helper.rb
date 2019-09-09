require_relative '../../lib/helpers/va_rules_test_helper.rb'
require_relative '../../lib/helpers/contact_segments_test_helper.rb'

module AutomationTestHelper
  include VaRulesTesthelper
  include Admin::Automation::AutomationSummary
  include Va::Constants
  include Admin::AutomationConstants
  include ContactSegmentsTestHelper

  def rules_pattern(rules, affected_tickets_counts = {})
    rules.map do |rule|
      automation_rule_pattern(rule, true, affected_tickets_counts[rule.id])
    end
  end

  def automation_rule_pattern(rule, list_page = false, affected_tickets_count = nil)
    automations_hash = default_rule_pattern(rule, list_page, affected_tickets_count)
    automations_hash[:actions] = actions_pattern(rule.action_data)
    automations_hash[:performer] = perfromer_pattern(rule.rule_performer) if rule.observer_rule?
    automations_hash[:events] = events_pattern(rule.rule_events) if rule.observer_rule?
    automations_hash[:conditions] = conditions_pattern(rule.rule_conditions, rule.rule_operator) if
        rule.observer_rule? || rule.dispatchr_rule? || rule.supervisor_rule?
    if nested?(rule.rule_conditions)
      automations_hash[:operator] = case(rule.rule_operator.try(:to_sym))
                                    when :any
                                      'condition_set_1 or condition_set_2'
                                    when :all
                                      "condition_set_1 and condition_set_2"
                                    else
                                      rule.rule_operator
                                    end
    end
    automations_hash
  end

  def default_rule_pattern(rule, list_page = false, affected_tickets_count = nil)
    automations_hash = {
      name: rule.name,
      position: rule.position,
      active: rule.active,
      outdated: rule.outdated,
      last_updated_by: rule.last_updated_by,
      id: rule.id,
      created_at: rule.created_at.try(:utc),
      summary: generate_summary(rule, true),
      updated_at: rule.updated_at.try(:utc)
    }
    automations_hash[:meta] = meta_hash(rule) unless list_page
    automations_hash[:affected_tickets_count] = affected_tickets_count if affected_tickets_count.present?
    automations_hash
  end

  def meta_hash(record)
    {
      total_active_count: Account.current.account_va_rules.where(rule_type: record.rule_type.to_i, active: true).count,
      total_count: Account.current.account_va_rules.where(rule_type: record.rule_type.to_i).count
    }
  end

  def perfromer_pattern(performer)
    return {} if performer.nil?
    performer_hash = {}
    performer_hash[:type] = performer.type.to_i unless performer.type.nil?
    performer_hash[:members] = performer.members unless performer.members.nil?
    performer_hash
  end

  def events_pattern(events)
    return [] if events.nil?
    events.map do |e|
      events_hash = {}
      events_hash[:field_name] = e.rule[:name] unless e.rule[:name].nil?
      events_hash[:to] = e.rule[:to] unless e.rule[:to].nil?
      events_hash[:from] = e.rule[:from] unless e.rule[:from].nil?
      events_hash[:value] = e.rule[:value] unless e.rule[:value].nil?
      events_hash
    end
  end

  def conditions_pattern(condition_data, operator)
    return {} if condition_data.nil?
    conditions_hash(condition_data,
                    operator)
  end

  def conditions_hash(condition_data, operator)
    nested_condition = (condition_data.first &&
        (condition_data.first.key?(:all) || condition_data.first.key?(:any)))
    if nested_condition
      conditions = []
      condition_data.each_with_index do |condition_set, index|
        conditions << {
          name: "condition_set_#{index + 1}",
          match_type: condition_set.keys.first,
          properties: condition_set_hash(condition_set.values.first)
        }
      end
      conditions
    else
      [{
        name: 'condition_set_1',
        match_type: operator,
        properties: condition_set_hash(condition_data)
      }]
    end
  end

  def condition_set_hash(condition_set)
    condition_set.map do |condition|
      condition_data = {}
      condition_data[:resource_type] = condition[:evaluate_on] || condition[:resource_type] || :ticket
      condition_data[:field_name] = condition[:name] unless condition[:name].nil?
      condition_data[:operator] = condition[:operator] unless condition[:operator].nil?
      condition_data[:custom_status_id] = condition[:custom_status_id] unless condition[:custom_status_id].nil?
      condition_data[:value] = condition[:value] unless condition[:value].nil?
      condition_data[:value] = transform_value(condition_data[:value], :array) if !condition_data[:value].is_a?(Array) && ARRAY_VALUE_OPERATORS.include?(condition[:operator].to_sym)
      condition_data[:case_sensitive] = condition[:case_sensitive] unless condition[:case_sensitive].nil?
      condition_data
    end
  end

  def actions_pattern(action_data)
    return {} if action_data.nil?
    action_data.map do |a|
      action_hash = {}
      action_hash[:field_name] = a[:name] unless a[:name].nil?
      %i[value email_to email_subject email_body request_type
         url need_authentication username password api_key custom_headers
         content_layout params responder_id].each do |key|
        action_hash.merge!(key.to_sym => a[key.to_sym]) unless a[key.to_sym].nil?
      end
      action_hash
    end
  end

  def sample_supervisor_json_without_conditions
    supervisor_payload = JSON.parse('{"active": true,"actions":[{"field_name":"priority","value":4}]}')
    supervisor_payload['name'] = Faker::Lorem.characters(20)
    supervisor_payload
  end

  def set_default_fields(sample_response)
    sample_response['outdated'] = false
    sample_response['last_updated_by'] = User.current.id
    sample_response
  end

  def observer_rule_json_with_thank_you_note
    observer_payload = JSON.parse('{ "active": true, "performer": { "type": 2 }, "events": [{ "field_name": "reply_sent" }, { "field_name": "note_type", "value": "public" }], "operator": "condition_set_1 and condition_set_2", "conditions": [{ "name": "condition_set_1", "match_type": "all", "properties": [{ "resource_type": "ticket", "field_name": "freddy_suggestion", "operator": "is_not", "value": "thank_you_note" }, { "resource_type": "ticket", "field_name": "status", "operator": "in", "value": [3, 4] }] }, { "name": "condition_set_2", "match_type": "any", "properties": [{ "resource_type": "ticket", "field_name": "status", "operator": "not_in", "value": [2, 4, 5] }] } ], "actions": [{ "field_name": "status", "value": 2 }] }')
    observer_payload['name'] = Faker::Lorem.characters(20)
    observer_payload
  end

  def valid_request_dispatcher_with_ticket_conditions(condition_field_name, action_field_name = :priority, resource_type = :ticket)
    {
      name: Faker::Lorem.characters(10),
      active: true,
      conditions: [{  name: 'condition_set_1',
                      match_type: 'all',
                      properties: generate_request_condition_data(condition_field_name, resource_type) }],
      actions: generate_request_actions(action_field_name)
    }
  end

  def valid_request_observer(event_field_name, condition_field_name = :subject, action_field_name = :priority)
    {
      name: Faker::Lorem.characters(10),
      active: true,
      performer: { type: 1 },
      conditions: [{  name: 'condition_set_1',
                      match_type: 'all',
                      properties: generate_request_condition_data(condition_field_name) }],
      actions: generate_request_actions(action_field_name),
      events: generate_events(event_field_name)
    }
  end

  def generate_request_condition_data(field_name, resource_type = :ticket)
    field_type = get_condition_field_type(field_name, resource_type)
    TYPE_TO_OPERATOR_MAPPING[field_type].map do |operator|
      value = generate_mock_value(field_type, field_name)
      value = transform_value(value, :array) if ARRAY_VALUE_OPERATORS.include?(operator)
      condition = { field_name: field_name.to_s, operator: operator.to_s }
      condition[:value] = value if value.present?
      condition[:resource_type] = resource_type.to_s
      condition[:case_sensitive] = false if CASE_SENSITIVE_TYPES.include?(field_type)
      condition
    end
  end

  def generate_request_actions(field_name)
    field_type = ACTIONS_FIELD_TO_TYPE_MAPPING[field_name]
    value = generate_mock_value(field_type, field_name)
    action = { field_name: transform_name(field_name).to_s }
    value = transform_value(value, :array) if ARRAY_VALUE_ACTIONS.include?(field_name.try(:to_sym))
    action[:value] = value if value.present?
    [action]
  end

  def generate_events(field_name)
    field_type = EVENTS_FIELD_TO_TYPE_MAPPING[field_name]
    value = generate_mock_value(field_type, field_name)
    event = { field_name: transform_name(field_name).to_s }

    if value.present?
      if field_name == :note_type
        event[:value] = value
      else
        event[:from] = value
        event[:to] = value
      end
    end
    [event]
  end

  def ceate_contact_segments
    input_params = [{ name: 'tag_names', value: ['test1'], operator: 'is_in' }]
    create_segment(input_params)
  end

  def dispatcher_create_test(field_name, action_field_name = :priority, resource_type = :ticket)
    va_rule_request = valid_request_dispatcher_with_ticket_conditions(field_name, action_field_name, resource_type)
    post :create, construct_params({ rule_type: VAConfig::RULES[:dispatcher] }.merge(va_rule_request), va_rule_request)
    assert_response 201
    parsed_response = JSON.parse(response.body)
    @va_rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(@va_rule_id)
    @status = nil
    match_custom_json(parsed_response, va_rule_request.merge!(default_rule_pattern(rule, false)))
  end

  def observer_create_test(event_field_name, condition_field_name = :subject, action_field_name = :priority)
    Account.current.account_va_rules.destroy_all
    va_rule_request = valid_request_observer(event_field_name, condition_field_name, action_field_name)
    post :create, construct_params({ rule_type: VAConfig::RULES[:observer] }.merge(va_rule_request), va_rule_request)

    assert_response 201
    parsed_response = JSON.parse(response.body)
    @va_rule_id = parsed_response['id'].to_i
    rule = Account.current.account_va_rules.find(@va_rule_id)
    match_custom_json(parsed_response, va_rule_request.merge!(default_rule_pattern(rule, false)))
  end

  def nested?(conditions)
    conditions.first && (conditions.first.key?(:all) || conditions.first.key?(:any))
  end
end
