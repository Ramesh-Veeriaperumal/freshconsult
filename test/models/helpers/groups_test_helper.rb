module ModelsGroupsTestHelper
  def create_group(account, options= {},group_type= 1)
    group = account.groups.find_by_name(options[:name])
    return group if group
    name = options[:name] || Faker::Name.name
    group = FactoryGirl.build(:group,:name=> name)
    group.account_id = account.id
    group.group_type = group_type
    group.ticket_assign_type  = options[:ticket_assign_type] if options[:ticket_assign_type]
        group.toggle_availability = options[:toggle_availability] if options[:toggle_availability]
    group.save!
    group
  end

  def create_group_with_agents(account, options= {},group_type= 1)
    group = account.groups.find_by_name(options[:name])
    return group if group
    name = options[:name] || Faker::Name.name
    group = FactoryGirl.build(:group,:name=> name)
    group.account_id = account.id
    group.group_type = group_type
    group.ticket_assign_type = options[:ticket_assign_type] if options[:ticket_assign_type]
    options[:agent_list].each { |agent| group.agent_groups.build(:user_id =>agent) } unless options[:agent_list].blank?
    group.save!
    group
  end

  def central_publish_group_pattern(group)
    {
      id: group.id,
      name: group.name,
      description: group.description,
      account_id: group.account_id,
      group_type: group.group_type,
      email_on_assign: group.email_on_assign,
      escalate_to: group.escalate_to,
      assign_time: group.assign_time,
      created_at: group.created_at.try(:utc).try(:iso8601),
      updated_at: group.updated_at.try(:utc).try(:iso8601),
      import_id: group.import_id,
      ticket_assign_type: group.ticket_assign_type,
      business_calendar_id: group.business_calendar_id,
      toggle_availability: group.toggle_availability,
      capping_limit: group.capping_limit,
      agents: group.agents.map do |ag|
        { name: ag.name, id: ag.id, email: ag.email }
      end
    }
  end

  def central_publish_group_destroy_pattern(group)
    {
      id: group.id,
      account_id: group.account_id
    }
  end
end
