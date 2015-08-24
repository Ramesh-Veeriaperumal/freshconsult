module Freshfone::AgentsLoader

  def load_available_and_busy_agents
    load_group_hunt_agents(current_number.group_id) and return if current_number.group.present?
    initialize_agents freshfone_users.load_agents(current_number)
    self.routing_type = :simple_routing
    @call_actions.save_conference_meta(:simple_routing)
  end

  def load_group_hunt_agents(group_id)
    initialize_agents freshfone_users.load_agents(current_number, group_id)
    @call_actions.save_conference_meta(:group, group_id)
  end

  def load_agent(agent_id, freshfone_user=nil)
    freshfone_user = freshfone_users.find_by_user_id(agent_id) if freshfone_user.blank?
    initialize_agents({ :available_agents => freshfone_user && freshfone_user.online? ? [freshfone_user] : [],
                        :busy_agents      => freshfone_user && freshfone_user.busy? ? [freshfone_user] : [] })
    @call_actions.save_conference_meta(:agent, agent_id)
  end

  def initialize_agents(agents)
    self.available_agents = agents[:available_agents]
    self.busy_agents      = agents[:busy_agents]
  end

end