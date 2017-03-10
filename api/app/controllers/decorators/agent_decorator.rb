class AgentDecorator < ApiDecorator

  include Gamification::GamificationUtil

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
      role_ids:  record.user.user_roles.map(&:role_id),
      available_since: record.active_since.try(:utc),
      contact: ContactDecorator.new(record.user, {}).to_hash,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }
  end

  def to_full_hash
    [agent_hash, additional_agent_info, gamification_options].inject(&:merge)
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

  private

    def additional_agent_info
      {
        last_active_at:       record.last_active_at.try(:utc),
        assumable_agents:     record.assumable_agents.map(&:id),
        abilities:            record.user.abilities,
        preferences:          record.preferences
      }
    end

    def gamification_options
      return {} unless gamification_feature?(Account.current)
      {
        points:               record.points,
        scoreboard_level_id:  record.scoreboard_level_id,
        next_level_id:        record.next_level.try(:id)
      }
    end
end
