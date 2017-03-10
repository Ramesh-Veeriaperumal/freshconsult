module BootstrapTestHelper
  include AgentsTestHelper
  
  def index_pattern(agent, account)
    {
      agent: agent_info_pattern(agent),
      account: account_info_pattern(account)
    }
  end

  def agent_info_pattern(agent)
    ret_hash = private_api_agent_pattern({}, agent).merge({
      last_active_at: agent.last_active_at.try(:utc).try(:iso8601),
      abilities: agent.user.abilities,
      assumable_agents: agent.assumable_agents.map(&:id),
      preferences: agent.preferences
    })
    if Account.current.gamification_enabled? && Account.current.gamification_enable_enabled?
      ret_hash.merge!({
        points: agent.points,
        scoreboard_level_id: agent.scoreboard_level_id,
        next_level_id: agent.next_level.try(:id)
      })
    end
    ret_hash
  end

  def account_info_pattern(account)
    pattern = {
      full_domain: account.full_domain,
      helpdesk_name: account.helpdesk_name,
      name: account.name,
      time_zone: account.time_zone,
      date_format: Hash,
      features: Array,
      launched: Array,
      settings: {
        personalized_email_replies: wildcard_matcher,
        compose_email_enabled: wildcard_matcher,
        include_survey_manually: wildcard_matcher
      },
      agents: Array,
      groups: Array
    }
    if User.current.privilege?(:manage_users) || User.current.privilege?(:manage_account)
      pattern.merge!(subscription: {
        agent_limit: account.subscription.agent_limit,
        state: account.subscription.state,
        addons: account.subscription.addons,
        subscription_plan: String
      })
    end
    pattern
  end
end
