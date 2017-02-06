class AgentDecorator < ApiDecorator

  CONTACT_FIELDS = [:active, :email, :job_title, :language, :mobile, :name, :phone, :time_zone, :avatar].freeze

  def to_hash
    {
      available: record.available,
      occasional: record.occasional,
      id: record.user_id,
      ticket_scope: record.ticket_permission,
      signature: record.signature_html,
      group_ids: record.group_ids,
      role_ids:  record.user.role_ids,
      available_since: record.active_since.try(:utc),
      contact: ContactDecorator.new(record.user, {}).to_hash.slice(*CONTACT_FIELDS),
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }
  end

  def to_full_hash
    to_hash.merge({
      last_active_at:       record.last_active_at.try(:utc),
      points:               record.points,
      scoreboard_level_id:  record.scoreboard_level_id,
      assumable_agents:     record.assumable_agents.map(&:id),
      next_level:           record.next_level,
      abilities:            record.user.abilities,
      preferences:          record.preferences
    })
  end
end
