class AgentDecorator < ApiDecorator
  def initialize(record, options = {})
    super(record)
  end

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
      contact: ContactDecorator.new(record.user, {}).to_hash.slice(*contact_fields),
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
    }
  end

  def contact_fields
    [:active, :email, :job_title, :language, :mobile, :name, :phone, :time_zone, :avatar]
  end
end
