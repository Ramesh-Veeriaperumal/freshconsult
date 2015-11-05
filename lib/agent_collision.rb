module AgentCollision

  def self.channel(account)
    "/#{account.full_domain}/#{NodeConfig["agent_collision_channel"]}/**"
  end

  def self.ticket_view_channel(account,ticket_id)
    "/#{account.full_domain}/#{NodeConfig["agent_collision_channel"]}/#{ticket_id}/view"
  end

  def self.ticket_replying_channel(account,ticket_id)
    "/#{account.full_domain}/#{NodeConfig["agent_collision_channel"]}/#{ticket_id}/reply"
  end

  def self.ticket_channel(account,ticket_id)
    "/#{account.full_domain}/#{NodeConfig["agent_collision_channel"]}/#{ticket_id}"
  end
  
end
