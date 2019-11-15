module Admin::SkillsTestHelper
  include Admin::SkillConstants

  def construct_skill_param(resource_type, field_name, custom = nil)
    conditions = case custom
                 when :nested_fields
                   [construct_nested_condition(resource_type)]
                 when :custom_dropdown
                   [construct_dropdown_condition(resource_type)]
                 else
                   [construct_condition(resource_type, field_name)]
                 end
    { name: Faker::Lorem.characters(10), agents: [{ id: Account.current.agents.pluck_all(:user_id).sample }], match_type: 'all', conditions: conditions }
  end

  def construct_nested_condition(resource_type)
    { resource_type: resource_type.to_s, field_name: 'test_custom_country', operator: 'is', value: 'USA',
      nested_fields: { level2: { field_name: 'test_custom_state', value: 'California' },
                       level3: { field_name: 'test_custom_city', value: 'Los Angeles' } } }
  end

  def construct_dropdown_condition(resource_type)
    { resource_type: resource_type.to_s, field_name: 'test_custom_dropdown',
      operator: 'in', value: ['Pursuit of Happiness', 'Armaggedon'] }
  end

  def construct_condition(resource_type, field_name)
    { resource_type: resource_type.to_s, field_name: field_name.to_s,
      operator: 'in', value: fetch_field_value(resource_type, field_name) }
  end

  def fetch_field_value(resource_type, field_name)
    case resource_type
    when :contact
      default_contact_field_values(field_name)
    when :company
      default_company_field_values(field_name)
    else
      default_ticket_field_values(field_name)
    end
  end

  def default_ticket_field_values(field_name)
    { priority: ApiTicketConstants::PRIORITIES, ticket_type: Account.current.ticket_type_values.pluck_all(:value),
      source: Account.current.products.pluck_all(:id), product_id: Account.current.products.pluck_all(:id),
      group_id: Account.current.groups.pluck_all(:id) }[field_name]
  end

  def default_contact_field_values(field_name)
    { language: %w[ar bs bg ca zh-CN zh-TW zh-HK hr cs da nl] }[field_name]
  end

  def default_company_field_values(field_name)
    { name: Account.current.companies_from_cache.map(&:name), domains: Account.current.company_domains.pluck_all(:domain) }[field_name]
  end

  def invalid_skill_param
    { name: Faker::Lorem.characters(10), agents: [{ id: 1 }], conditions: invalid_skill_conditions }
  end

  def invalid_skill_conditions
    [ { resource_type: 'ticket', field_name: 'priority', operator: 'in', value: [3456789, 34567890] },
      { resource_type: 'ticket', field_name: 'product_id', operator: 'in', value: [3456789, 34567890] } ]
  end

  def create_dummy_skill
    skill = Account.current.skills.build({ name: Faker::Name.name, match_type: "all",
                                           filter_data: [ { "evaluate_on"=>"ticket", "name"=>"priority", "operator"=>"in", "value"=>[1] } ] })
    skill.save
    skill
  end

  def valid_skill_field_value(field_name)
    { name: Faker::Name.name, match_type: "all", agents: Account.current.agents.pluck_all(:user_id).map { |a| { id: a } },
      conditions: [ { resource_type: 'ticket', field_name: 'priority',
                      operator: 'in', value: ApiTicketConstants::PRIORITIES }] }[field_name]
  end

  def skill_pattern_update_test(skill, test_field = nil)
    pattern = {
        id: skill.id,
        name: skill.name,
        rank: skill.position,
        created_at: skill.created_at,
        updated_at: skill.updated_at,
        agents: skill.user_ids.map { |a| { id: a } },
        match_type: skill.match_type,
        conditions: skill_condition_pattern(skill.filter_data)
    }
    test_field.present? ? pattern.except(test_field) : pattern
  end

  def skill_condition_pattern(conditions)
    result = []
    conditions.each do |condition|
      result << { resource_type: EVALUATE_ON_MAPPINGS[(condition['evaluate_on'] || condition[:evaluate_on]).try(:to_sym)].to_s,
                  field_name: condition['name'] || condition[:name], operator: condition['operator'] || condition[:operator],
                  value: condition['value'] || condition[:value] }
    end
    result
  end

  def get_skill_position
    (Account.current || Account.first).skills.where('id is not null').inject({}) do |hash, x|
      hash.merge!(x.position.to_s => x.id.to_s)
    end
  end

  INVALID_SKILL_PARAMS = [ { match_type: "or", agents: [{id: 78}, {id: 890}], conditions: [ { resource_type: 'tickets', field_name: 'priority', operator: 'in', value: ApiTicketConstants::PRIORITIES }] },
                           { match_type: "all", agents: [{id: 1}], conditions: [ { resource_type: 'ticket', field_name: 'prioritie', operator: 'in', value: ApiTicketConstants::PRIORITIES }] },
                           { match_type: "all", agents: [{id: 1}], conditions: [ { resource_type: 'contact', field_name: 'prioritie', operator: 'in', value: ApiTicketConstants::PRIORITIES }] },
                           { match_type: "all", agents: [{id: 1}], conditions: [ { resource_type: 'ticket', field_name: 'prioritie', operator: 'is_any_of', value: ApiTicketConstants::PRIORITIES }] },
                           { match_type: "all", agents: [{id: 1}], conditions: [ { resource_type: 'company', field_name: 'prioritie', operator: 'in', value: ApiTicketConstants::PRIORITIES }] },
                           { match_type: "and", agents: [{ id: 0 }, { id: 90 }], conditions: [ { resource_type: 'ticket', field_name: 'priority', operator: 'is', value: ApiTicketConstants::PRIORITIES }] },
                           { match_type: "all", agents: [{id: 1}], conditions: [ { resource_type: 'ticket', field_name: 'statuses', operator: 'in', value: ApiTicketConstants::PRIORITIES }] },
                           { match_type: "all", agents: [{id: 1}], conditions: [ { resource_type: 'tickets', field_name: 'nested_level1', operator: 'in', value: 'random1',
                                                                                                                                       nested_fields: { level2: { field_name: 'nested_level2', value: 'random2' }, level3: { field_name: 'nested_level3', value: 'random3' } } } ] },
                           { match_type: "all", agents: [{id: 1}], conditions: [ { resource_type: 'ticket', field_name: 'rand_nested_level1', operator: 'is', value: 'random1',
                                                                                                                                       nested_fields: { level2: { field_name: 'nested_level2', value: 'random2' }, level3: { field_name: 'nested_level3', value: 'random3' } } } ] } ].map { |param| param.merge!(name: Faker::Name.name) }
end