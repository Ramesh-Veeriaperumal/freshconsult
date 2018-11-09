class ProfileDecorator < ApiDecorator

  def initialize(record, options)
    super(record)
  end

  def agent_hash
    {
      available:        record.available,
      occasional:       record.occasional,
      id:               record.user_id,
      ticket_scope:     record.ticket_permission,
      signature:        record.signature_html,
      group_ids:        record.group_ids,
      role_ids:         record.user.role_ids,
      available_since:  record.active_since.try(:utc),
      contact:          ContactDecorator.new(record.user, {}).to_hash,
      created_at:       created_at.try(:utc),
      updated_at:       updated_at.try(:utc),
      type:             Account.current.agent_types_from_cache.find { |type| type.agent_type_id == record.agent_type }.name
    }
  end

  def to_hash
    agent_hash
  end

  def to_full_hash
    [agent_hash, additional_agent_info].inject(&:merge)
  end

  def api_me_hash
    hash = agent_hash
    hash[:contact].delete(:avatar)
    hash[:contact].merge!({ created_at: record.user.created_at, updated_at: record.user.updated_at, last_login_at: record.user.last_login_at.try(:utc) })
    hash
  end
  
  def show_agent_hash version
    return api_me_hash if version == 'v2'
    to_full_hash
  end

  private

    def additional_agent_info
      {
        last_active_at:   record.last_active_at.try(:utc),
        assumable_agents: record.assumable_agents.map(&:id),
        preferences:      record.preferences,
        api_key:          record.user.single_access_token
      }
    end

end
