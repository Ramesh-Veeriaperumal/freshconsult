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
      ticket_permission: ticket_permission_hash(agent),
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
      agent_type: agent_type_hash(agent),
      freshid_uuid: freshid_user_uuid,
      groups: agent.groups.reload.map { |ag| {name: ag.name, id: ag.id }},
      contribution_groups: agent.all_agent_groups.reload.preload(:group).where(write_access: false).map { |ag| { name: ag.group.name, id: ag.group.id } }
    }.merge(user_fields_pattern(agent.user))
  end

  def event_info_pattern()
    {
      ip_address: Thread.current[:current_ip],
      pod: ChannelFrameworkConfig['pod']
    }
  end

  def ticket_permission_hash(agent)
    {
      id: agent.ticket_permission,
      permission: Agent::PERMISSION_TOKENS_BY_KEY[agent.ticket_permission].to_s
    }
  end

  def agent_type_hash(agent)
    {
      id: agent.agent_type,
      name: AgentType.agent_type_name(agent.agent_type)
    }
  end

  def freshid_user_uuid
    (Account.current.freshid_integration_enabled? && agent.user.freshid_authorization.try(:uid)) || nil
  end

  def user_fields_pattern(user)
    USER_FIELDS.inject({}) do |h, key|
      h.merge(key => user.safe_send(key))
    end
  end

  def out_of_office
    return unless Account.current.out_of_office_enabled?
       
    5
  end
end
