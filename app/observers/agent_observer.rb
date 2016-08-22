class AgentObserver < ActiveRecord::Observer

  include MemcacheKeys

  def before_create(agent)
    set_default_values(agent)
  end

  def before_update(agent)
    update_agents_level(agent)
  end
  
  def after_commit(agent)
    if agent.send(:transaction_include_action?, :create)
      update_crm(agent) 
    end
    true
  end

  def after_save(agent)
    update_agent_levelup(agent)
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

      
    def update_crm(agent)
      if agent.account.full_time_agents.count > 1
        Resque.enqueue_at(15.minutes.from_now, CRM::AddToCRM::UpdateTrialAccounts, { :account_id => agent.account_id })
      end
    end
end
