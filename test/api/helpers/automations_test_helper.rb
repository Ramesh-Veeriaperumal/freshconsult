module AutomationTestHelper
  include Admin::Automation::AutomationSummary
  include Va::Constants
  include Admin::AutomationConstants

  def rules_pattern(rules)
    rules.map do |rule|
      automation_rule_pattern(rule, true)
    end
  end

  def automation_rule_pattern(rule, list_page = false)
    automations_hash = {
        name: rule.name,
        position: rule.position,
        active: rule.active,
        actions: actions_pattern(rule.action_data),
        outdated: rule.outdated,
        last_updated_by: rule.last_updated_by,
        id: rule.id,
        created_at: rule.created_at.try(:utc),
        summary: generate_summary(rule, true),
        updated_at: rule.updated_at.try(:utc)
      }
      automations_hash.merge!(meta: meta_hash(rule)) unless list_page
      automations_hash.merge!({performer: perfromer_pattern(rule.rule_performer)}) if rule.observer_rule?
      automations_hash.merge!({events: events_pattern(rule.rule_events)}) if rule.observer_rule?
      automations_hash.merge!({conditions: conditions_pattern(rule.rule_conditions, rule.rule_operator)}) if
          rule.observer_rule? || rule.dispatchr_rule? || rule.supervisor_rule?
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
      conditions = {}
      condition_data.each_with_index do |condition_set, index|
        conditions[:operator] = READABLE_OPERATOR[operator.to_s] if index == 1
        conditions["condition_set_#{index + 1}".to_sym] = condition_set_hash(condition_set.values.first,
                                                                             condition_set.keys.first)
      end
      conditions
    else
      { 'condition_set_1'.to_sym => condition_set_hash(condition_data, operator) }
    end
  end

  def condition_set_hash(condition_set, match_type)
    return {} if condition_set.nil?
    condition_hash = { match_type: match_type }
    condition_set.each do |condition|
      condition_data = {}
      evaluate_on_type = condition[:evaluate_on] || 'ticket'
      condition_hash[evaluate_on_type.to_sym] ||= []
      condition_data[:field_name] = condition[:name] unless condition[:name].nil?
      condition_data[:operator] = condition[:operator] unless condition[:operator].nil?
      condition_data[:value] = condition[:value] unless condition[:value].nil?
      condition_data[:case_sensitive] = condition[:case_sensitive] unless condition[:case_sensitive].nil?
      condition_data[:case_sensitive] = false if DEFAULT_TEXT_FIELDS.include?(condition[:name].to_sym) &&
                                                !condition.key?(:case_sensitive) && condition[:last_updated_by].present?
      condition_data = support_for_old_operators(condition_data)
      condition_hash[evaluate_on_type.to_sym] << condition_data
    end
    condition_hash
  end

  def support_for_old_operators(data)
    data.symbolize_keys!
    if data[:operator].is_a?(String) && NEW_ARRAY_VALUE_OPERATOR_MAPPING.key?(data[:operator].to_sym)
      data[:value] = *data[:value]
      data[:operator] = NEW_ARRAY_VALUE_OPERATOR_MAPPING[data[:operator].to_sym]
    end
    data
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

  def create_dispatcher_rule
    VaRule.create(
      rule_type: VAConfig::BUSINESS_RULE,
      name: Faker::Lorem.characters(10),
      match_type: 'any',
      filter_data: [{ evaluate_on: 'ticket', name: 'subject_or_description',
                      operator: 'contains_any_of', value: ['return'] }],
      action_data: [{ name: 'group_id', value: 2 }],
      active: true,
      description: Faker::Lorem.characters(20),
      condition_data: { all: [
        { any: [{ evaluate_on: 'ticket', name: 'subject_or_description',
                  operator: 'contains_any_of', value: ['return'] }] }
      ] }
    )
  end

  def sample_json_for_observer
    observer_payload = JSON.parse('{"active":true,"performer":{"type":1},
    "events":[{"field_name":"priority","from":1,"to":2},{"field_name":"ticket_type","from":"Question","to":"Incident"},
    {"field_name":"status","from":3,"to":4}],"conditions":{"condition_set_1":{"match_type":"all","ticket":[{"field_name":"group_id","operator":"in","value":[1]}]}},
      "actions":[{"field_name":"group_id","value":1}]}')
    observer_payload['name'] = Faker::Lorem.characters(20)
    observer_payload
  end

  def sample_json_for_dispatcher
    dispatcher_payload = JSON.parse('{"name":"test 1234423","active":false,
      "conditions":{"condition_set_1":{"match_type":"all","ticket":[{"field_name":"ticket_type","operator":"in","value":["Refund"]}]},
      "operator":"or","condition_set_2":{"match_type":"all","ticket":[{"field_name":"ticket_type","operator":"in","value":["Question"]},
        {"field_name":"subject_or_description","operator":"contains","value":["billing"]}]}},"actions":[{"field_name":"status","value":2}] }')
    dispatcher_payload['name'] = Faker::Lorem.characters(20)
    dispatcher_payload
  end

  def set_default_fields(sample_response)
    sample_response['outdated'] = false
    sample_response['last_updated_by'] = User.current.id
    sample_response
  end

  def observer_rule_json_with_thank_you_note
    observer_payload = JSON.parse('{ "active": true, "performer": { "type": 2 }, "events": [ { "field_name": "reply_sent" }, { "field_name": "note_type", "value": "public" } ], "conditions": { "condition_set_1": { "match_type": "all", "ticket": [ { "field_name": "freddy_suggestion", "operator": "is_not", "value": "thank_you_note" }, { "field_name": "status", "operator": "in", "value": [ 3, 4 ] } ] }, "operator": "and", "condition_set_2": { "match_type": "any", "ticket": [ { "field_name": "status", "operator": "not_in", "value": [ 2, 4, 5 ] } ] } }, "actions": [ { "field_name": "status", "value": 2 } ] }')
    observer_payload['name'] = Faker::Lorem.characters(20)
    observer_payload
  end
end
