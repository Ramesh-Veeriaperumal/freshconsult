class AgentDecorator < ApiDecorator
  CONTACT_FIELDS = [:active, :email, :job_title, :language, :mobile, :name, :phone, :time_zone, :avatar].freeze

  def initialize(record, options)
    super(record)
    @agent_groups = options[:agent_groups]
  end

  def to_hash
    User.current.privilege?(:manage_users) ? agent_hash : to_restricted_hash
  end

  def agent_hash
    {
      available: record.available,
      occasional: record.occasional,
      id: record.user_id,
      ticket_scope: record.ticket_permission,
      signature: record.signature_html,
      group_ids: group_ids,
      role_ids:  record.user.role_ids,
      available_since: record.active_since.try(:utc),
      contact: ContactDecorator.new(record.user, {}).to_hash.slice(*CONTACT_FIELDS),
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }
  end

  def to_full_hash
    agent_hash.merge({
      last_active_at:       record.last_active_at.try(:utc),
      points:               record.points,
      scoreboard_level_id:  record.scoreboard_level_id,
      assumable_agents:     record.assumable_agents.map(&:id),
      next_level:           record.next_level,
      abilities:            record.user.abilities,
      preferences:          record.preferences
    })
  end

  def to_restricted_hash
    if record.is_a?(User)
      user_obj = record
    else
      user_obj = record.user
    end
    {
      id: user_obj.id,
      contact: {
        name: user_obj.name,
        email: user_obj.email
      },
      group_ids: group_ids
    }
  end

  def group_ids
    if @agent_groups
      @agent_groups.map do |agent_group|
        agent_group.group_id if agent_group.user_id == (record.is_a?(User) ? record.id : record.user_id)
      end.compact.uniq
    else
      record.agent_groups.map(&:group_id)
    end
  end
end
