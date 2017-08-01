class AgentDecorator < ApiDecorator
  include Gamification::GamificationUtil

  def initialize(record, options)
    super(record)
    @group_mapping_ids = options[:group_mapping_ids]
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
    user_obj = if record.is_a?(User)
                 record
               else
                 record.user
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
    (@group_mapping_ids || record.agent_groups.map(&:group_id) || []).compact.uniq
  end

  def agent_achievements_hash
    return {} unless gamification_feature?(Account.current)

    next_level = record.next_level || Account.current.scoreboard_levels.next_level_for_points(record.points.to_i).first
    points_needed = next_level.points - record.points.to_i if next_level

    {
      id: record.user_id,
      points: record.points.to_i,
      current_level_name: record.level.try(:name),
      next_level_name: next_level.try(:name),
      points_needed: (points_needed || 0),
      badges: record.user.quests.order('`achieved_quests`.`created_at` DESC').pluck(:badge_id)
    }
  end

  def availability_hash(all_agent_channels_hash)
    agent_hash.merge!(all_agent_channels_hash)
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
