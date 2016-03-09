class GroupDecorator < ApiDecorator
  delegate :id, :name, :description, :escalate_to, to: :record

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
    record.agent_groups.map(&:user_id)
  end

  def business_hour_id
    record.business_calendar_id
  end

  def auto_ticket_assign
    to_bool(:ticket_assign_type)
  end
end

