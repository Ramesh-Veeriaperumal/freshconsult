module AgentGroupTestHelper

  def create_agent_group(account, options= {})
    agent_group = account.agent_groups.first
    return agent_group if agent_group

    group = FactoryGirl.build(:group,:name=> name)
    group.account_id = account.id
    group.ticket_assign_type  = options[:ticket_assign_type] if options[:ticket_assign_type]
    group.toggle_availability = options[:toggle_availability] if options[:toggle_availability]
    group.save

    agent = Account.current.agents.first
    agent.save

    test_agent_group = FactoryGirl.build(:agent_group,
      :user_id => agent.user_id, 
      :group_id => group.id,
      :account_id => account.id,
      :created_at => Time.now.utc,
      :updated_at => Time.now.utc)
    
    test_agent_group.save
    test_agent_group
  end

  def central_publish_agent_group_pattern(agent_group)
    {
      id: agent_group.id,
      user_id: agent_group.user_id,
      group_id: agent_group.group_id,
      account_id: agent_group.account_id,
      created_at: agent_group.created_at.try(:utc).try(:iso8601),
      updated_at: agent_group.updated_at.try(:utc).try(:iso8601)
    }

  end

end
