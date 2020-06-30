require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')

module AdvancedScopeTestHelper
  include GroupsTestHelper

  def create_agent_group_with_write_access(account, agent)
    group = create_group_with_agents(account, agent_list: [agent.id])
    agent_group = agent.agent_groups.where(group_id: group.id).first
    agent_group.write_access = true
    agent_group.save!
    agent_group
  end

  def create_agent_group_with_read_access(account, agent)
    group = create_group_with_agents(account, agent_list: [agent.id])
    agent_group = agent.agent_groups.where(group_id: group.id).first
    agent_group.write_access = false
    agent_group.save!
    agent_group
  end
end
