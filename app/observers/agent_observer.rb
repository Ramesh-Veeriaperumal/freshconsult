class AgentObserver < ActiveRecord::Observer

  include MemcacheKeys
  include RoundRobinCapping::Methods
  include Freshcaller::AgentUtil

  def before_create(agent)
    set_default_values(agent)
  end

  def before_update(agent)
    update_agents_level(agent)
  end
  
  def after_commit(agent)
    create_update_fc_agent(agent) if save_fc_agent?(agent)
    true
  end

  def after_save(agent)
    update_agent_levelup(agent)
  end

  def after_update(agent)
    handle_capping(agent)
    sync_to_export_service(agent)
  end

  protected
    def set_default_values(agent)
      agent.account_id = agent.user.account_id
      agent.ticket_permission = Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets] if agent.ticket_permission.blank?
    end

    def update_agents_level(agent)
      return unless agent.points_changed?

      level = agent.user.account.scoreboard_levels.level_for_score(agent.points).first
      if level and !(agent.scoreboard_level_id.eql? level.id)
        agent.level = level
      end
    end

    def update_agent_levelup(agent)
      return unless agent.scoreboard_level_id_changed?
      new_point = agent.user.account.scoreboard_levels.find(agent.scoreboard_level_id).points
      if agent.level and ((agent.points ? agent.points : 0) < new_point)
        SupportScore.add_agent_levelup_score(agent.user, new_point)
      end 
    end

    def handle_capping(agent)
      return unless agent.available_changed?
      Groups::SyncAndAssignTickets.perform_async({ agent_id: agent.id })
    end

    def sync_to_export_service(agent)
      agent.user.sync_to_export_service if agent.ticket_permission_changed?
    end
end
