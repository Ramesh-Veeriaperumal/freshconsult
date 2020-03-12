require "#{Rails.root}/test/api/helpers/json_pattern.rb"

module Automation::ConditionValidationTestHelper
  include JsonPattern
  include Admin::AutomationConstants

  VALUE_HASH = {
    email: %w[testing@mail.com test@mail.com],
    object_id: [2, 3],
    tags: %w[test test1],
    text: %w[random faker],
    date_time: %w[2019-08-24 2019-03-21],
    number: [8, 6],
    hours: [24, 72],
    date_time_status: [24, 72],
    date: %w[2019-08-24 2019-03-21],
    choicelist: ['At risk', 'Doing okay']
  }.freeze

  FIELD_NAME_VALUE_MAPPING = {
    ticket_type: %w[Question Request],
    responder_id: Account.first.technicians.map(&:id),
    time_zone: %w[Alaska Arizona]
  }.freeze

  INVALID_HASH = [
      { name: 'status', operator: 'in', value: %w[Open Closed], field_type: 'object_id', error: "Expecting 'Integer' but found 'invalid'" }, # object_id
      { name: 'tag_names', operator: 'in', value: [1, 2], field_type: 'tags', error: "Expecting 'String' but found 'invalid'" }, # tags
      { name: 'from_email', operator: 'in', value: [1, 2], field_type: 'email', error: "Expecting 'String' but found 'invalid'" }, # email
      { name: 'subject', operator: 'is', value: [1, 2], field_type: 'text', error: "Expecting 'String' but found 'invalid'" }, # text
      { name: 'created_at', operator: 'during', value: [1, 2], field_type: 'date_time', error: "Expecting 'String' but found 'invalid'" }, # date_time
  ].freeze

  COMPANY_FIELD_TYPES = %i[object_id choicelist date].freeze

  CONTACT_FIELD_TYPES = %i[email text choicelist].freeze

  def automation_validation_class
    'Admin::AutomationValidation'.constantize
  end

  def construct_default_params(field_type)
    field = fetch_field_by_type(field_type).map { |field_hash| { name: field_hash[:name], type: field_hash[:field_type] } }.first
    case field[:type].to_sym
    when :object_id
      name_value = FIELD_NAME_VALUE_MAPPING.first
      rule_params(condition_params(name_value[0].to_s, field[:type], name_value[1]))
    else
      rule_params(condition_params(field[:name], field[:type]))
    end
  end

  def fetch_field_by_type(field_type)
    CONDITION_TICKET_FIELDS_HASH.select { |field| field[:field_type] == field_type }
  end

  def rule_params(conditions)
    dispatcher_payload = JSON.parse('{"name":"test 1234423","active":true,
                          "actions":[{"field_name":"status","value":2}] }')
    dispatcher_payload['conditions'] = [conditions]
    dispatcher_payload
  end

  def condition_params(field_name, field_type, field_values = nil, resource_type = :ticket)
    operators = FIELD_TYPE[field_type]
    values = field_values || VALUE_HASH[field_type]
    operator = operators.first
    value = ARRAY_VALUE_EXPECTING_OPERATOR.include?(operator) ? values : values[1]
    condition_skeleton(resource_type, field_name, operator, value)
  end

  def condition_skeleton(resource_type, field_name, operator, value)
    { name: 'condition_set_1', match_type: 'any', properties: [{ resource_type: resource_type.to_s,
                                                                 field_name: field_name.to_s,
                                                                 operator: operator.to_s,
                                                                 value: value }] }
  end

  def agent_shift_field_condition_params(availability)
    { name: 'condition_set_1', match_type: 'any', properties: [{ resource_type: 'ticket',
                                                                 field_name: 'responder_id', operator: 'in',
                                                                 value: Account.current.agents.pluck(:id),
                                                                 related_conditions: [
                                                                   field_name: 'agent_availability',
                                                                   operator: 'is', value: availability
                                                                 ] }] }
  end

  def agent_ooo_condition_params(availability_value, ooo_field_name, operator, value)
    {
      name: 'condition_set_1', match_type: 'any', properties: [{ resource_type: 'ticket',
                                                                 field_name: 'responder_id', operator: 'in',
                                                                 value: Account.current.agents.pluck(:id),
                                                                 related_conditions: [{
                                                                   field_name: 'agent_availability',
                                                                   operator: 'is', value: availability_value,
                                                                   related_conditions: [{
                                                                     field_name: ooo_field_name,
                                                                     operator: operator,
                                                                     value: value
                                                                   }]
                                                                 }] }]

    }
  end

  def construct_customer_params(field_type, customer)
    if customer == :company
      field = fetch_company_field_by_type(field_type)
      values = field_type == :object_id ? %w[Basic Premium] : nil
      name = field_type == :object_id ? 'account_tier' : field[:name]
    else
      field = fetch_contact_field_by_type(field_type)
      name = field[:name]
      values = FIELD_NAME_VALUE_MAPPING[name.to_sym]
    end
    rule_params(condition_params(name, field[:field_type], values, customer))
  end

  def fetch_company_field_by_type(field_type)
    CONDITION_COMPANY_FIELDS_HASH.select { |field| field[:field_type] == field_type }.first
  end

  def fetch_contact_field_by_type(field_type)
    CONDITION_CONTACT_FIELDS_HASH.select { |field| field[:field_type] == field_type }.first
  end
end
