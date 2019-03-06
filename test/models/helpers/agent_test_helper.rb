module AgentTestHelper
  USER_FIELDS = [:name, :email, :last_login_ip, :current_login_ip, :login_count, 
    :failed_login_count, :active, :customer_id, :job_title, :second_email, 
    :phone, :mobile, :twitter_id, :description, :time_zone, :posts_count, :deleted, 
    :user_role, :delta, :import_id, :fb_profile_id, :language, :blocked, :address, 
    :whitelisted, :external_id, :preferences, :helpdesk_agent, :privileges, :extn, 
    :parent_id, :unique_external_id, :last_login_at, :current_login_at, :last_seen_at, 
    :blocked_at, :deleted_at]

  def update_agent_availability
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
      last_active_at: agent.last_active_at.try(:utc).try(:iso8601),
      agent_type: agent.agent_type,
      groups: agent.groups.map { |ag| {name: ag.name, id: ag.id }}
    }.merge(user_fields_pattern(agent.user))
  end

  def user_fields_pattern(user)
    USER_FIELDS.inject({}) do |h, key|
      h.merge(key => user.safe_send(key))
    end
  end
end
