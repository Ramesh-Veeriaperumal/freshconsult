module AgentTestHelper

  def update_agent
    agent = Account.current.agents.first
    agent.available = !agent.available
    agent.save
  end

  def central_publish_post_pattern(agent)
    {
      id: agent.id,
      user_id: agent.user_id,
      signature: agent.signature,
      ticket_permission: agent.ticket_permission,
      occasional: agent.occasional,
      google_viewer_id: agent.google_viewer_id,
      signature_html: agent.signature_html,
      points: agent.points,
      scoreboard_level_id: agent.scoreboard_level_id,
      account_id: agent.account_id,
      available: agent.available,
      created_at: agent.created_at.try(:utc).try(:iso8601),
      updated_at: agent.updated_at.try(:utc).try(:iso8601),
      active_since: agent.active_since.try(:utc).try(:iso8601),
      last_active_at: agent.last_active_at.try(:utc).try(:iso8601)
    }
  end
end
