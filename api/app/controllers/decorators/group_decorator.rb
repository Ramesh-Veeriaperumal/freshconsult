class GroupDecorator < ApiDecorator
  delegate :id, :name, :description, :escalate_to, to: :record

  def initialize(record, options)
    super(record)
    @agent_groups = options[:agent_groups]
  end

  def to_hash
    User.current.privilege?(:manage_availability) ? to_full_hash : to_restricted_hash
  end

  def to_full_hash
    {
      id: record.id,
      name: record.name,
      description: record.description,
      escalate_to: record.escalate_to,
      unassigned_for: unassigned_for,
      business_hour_id: business_hour_id,
      agent_ids: agent_ids,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }.merge(record.round_robin_enabled? ? { auto_ticket_assign: auto_ticket_assign } : {})
  end

  def to_restricted_hash
    {
      id: record.id,
      name: record.name,
      agent_ids: agent_ids
    }
  end

  def round_robin_enabled?
    Account.current.features? :round_robin
  end

  def unassigned_for
    GroupConstants::UNASSIGNED_FOR_MAP.key(record.assign_time)
  end

  def agent_ids_from_db
    record.agent_groups.pluck(:user_id)
  end

  def agent_ids_from_loaded_record
    record.agent_groups.map(&:user_id).uniq
  end

  def agent_ids
    if @agent_groups
      @agent_groups.map do |agent_group|
        agent_group.user_id if agent_group.group_id == record.id
      end.compact
    else
      agent_ids_from_loaded_record
    end
  end

  def business_hour_id
    record.business_calendar_id
  end

  def auto_ticket_assign
    to_bool(:ticket_assign_type)
  end
end
