module Helpers::GroupsHelper
  include GroupHelper
  # Patterns
  def group_pattern(expected_output = {}, group)
    group_json = group_json(expected_output, group)
    group_json[:auto_ticket_assign] = (expected_output[:auto_ticket_assign] || group.ticket_assign_type).to_s.to_bool
    group_json[:agent_ids] = group.agent_groups.pluck(:user_id)
    group_json
  end

  def group_pattern_without_assingn_type(expected_output = {}, group)
    group_json = group_json(expected_output, group)
    group_json[:agent_ids] = group.agent_groups.pluck(:user_id)
    group_json
  end

  def group_pattern_for_index(expected_output = {}, group)
    group_json = group_json(expected_output, group)
    group_json[:auto_ticket_assign] = (expected_output[:auto_ticket_assign] || group.ticket_assign_type).to_s.to_bool
    group_json
  end

  def group_json(expected_output, group)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      name: expected_output[:name] || group.name,
      description: expected_output[:description] || group.description,
      business_calendar_id: expected_output[:business_calendar_id] || group.business_calendar_id,
      escalate_to: expected_output[:escalate_to] || group.escalate_to,
      unassigned_for: expected_output[:unassigned_for] || (GroupConstants::UNASSIGNED_FOR_MAP.key(group.assign_time)),
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  # Helpers
  def group_payload
    { group: v1_group_params }.to_json
  end

  def v2_group_payload
    v2_group_params.to_json
  end

  # private
  def v1_group_params
    { name: Faker::Name.name,  description: Faker::Lorem.paragraph, agent_list: '1,3' }
  end

  def v2_group_params
    { name: Faker::Name.name,  description: Faker::Lorem.paragraph, agent_ids: [1, 3] }
  end
end
