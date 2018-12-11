module AutomationTestHelper
  def rules_pattern(rules)
    rules.map do |rule|
      automation_rule_pattern(rule)
    end
  end

  def automation_rule_pattern(rule)
    automations_hash = {
        name: rule.name,
        position: rule.position,
        active: rule.active,
        actions: actions_pattern(rule.action_data),
        affected_tickets_count: 0,
        outdated: rule.outdated,
        last_updated_by: rule.last_updated_by,
        id: rule.id,
        created_at: rule.created_at.try(:utc),
        updated_at: rule.updated_at.try(:utc)
      }
      automations_hash.merge!({performer: perfromer_pattern(rule.rule_performer)}) if rule.observer_rule?
      automations_hash.merge!({events: events_pattern(rule.rule_events)}) if rule.observer_rule?
      automations_hash.merge!({conditions: conditions_pattern(rule.rule_conditions, rule.rule_operator)}) if 
          rule.observer_rule? || rule.dispatchr_rule? || rule.supervisor_rule?
      automations_hash
  end

  def perfromer_pattern(performer)
    return {} if performer.nil?
    performer_hash = {}
    performer_hash.merge!({type: performer.type}) unless performer.type.nil?
    performer_hash.merge!({members: performer.members}) unless performer.members.nil?
    performer_hash
  end

  def events_pattern(events)
    return [] if events.nil?
    events.map do |e|
      events_hash = {}
      events_hash.merge!({field_name: e.rule[:name]}) unless e.rule[:name].nil?
      events_hash.merge!({to:  e.rule[:to]}) unless e.rule[:to].nil?
      events_hash.merge!({from: e.rule[:from]}) unless e.rule[:from].nil?
      events_hash.merge!({value: e.rule[:value]}) unless e.rule[:value].nil?
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
      condition_data.each_with_index  do |condition_set, index|
        conditions[:operator] = operator if index == 1
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
      condition_data.merge!({field_name: condition[:name]}) unless condition[:name].nil?
      condition_data.merge!({operator: condition[:operator]}) unless condition[:operator].nil?
      condition_data.merge!({value: condition[:value]}) unless condition[:value].nil?
      condition_hash[evaluate_on_type.to_sym] << condition_data
    end
    condition_hash
  end

  def actions_pattern(action_data)
    return {} if action_data.nil?
    action_data.map do |a|
      action_hash = {}
      action_hash.merge!({field_name: a[:name]}) unless  a[:name].nil?
      %i[value email_to email_subject email_body request_type
        url need_authentication username password api_key custom_headers
        content_layout params].each do |key|
          action_hash.merge!(key.to_sym => a[key.to_sym]) unless  a[key.to_sym].nil?
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
                      operator: 'contains', value: 'return' }],
      action_data: [{ name: 'group_id', value: 2 }],
      active: true,
      description: Faker::Lorem.characters(20),
      condition_data: { all: [
        { any: [{ evaluate_on: 'ticket', name: 'subject_or_description',
                  operator: 'contains', value: 'return' }] }
      ] }
    )
  end
end
