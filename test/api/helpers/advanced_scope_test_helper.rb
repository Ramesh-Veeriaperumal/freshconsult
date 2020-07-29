module AdvancedScopeTestHelper

  def create_agent_group_with_write_access(account, agent)
    group = create_group_with_agents(account, agent_list: [agent.id])
    agent.agent_groups.where(group_id: group.id).first
  end

  def create_agent_group_with_read_access(account, agent)
    group = create_group_with_agents(account, agent_list: [agent.id], write_access: false)
    agent.all_agent_groups.where(group_id: group.id).first
  end

  def create_group_with_agents(account, options = {})
    group = account.groups.where(name: options[:name]).first
    return group if group

    name = options[:name] || Faker::Name.name
    group = FactoryGirl.build(:group, name: name)
    write_access = (options[:write_access].nil? ? true : options[:write_access])
    group.account_id = account.id
    group.group_type = options[:group_type] || GroupConstants::SUPPORT_GROUP_ID
    group.ticket_assign_type = options[:ticket_assign_type] if options[:ticket_assign_type]

    if options[:agent_list].present?
      options[:agent_list].each do |agent|
        group.agent_groups.build(user_id: agent, write_access: write_access)
      end
    end
    group.save!
    group
  end
end
