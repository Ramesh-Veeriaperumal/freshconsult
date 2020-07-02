class GroupDecorator < ApiDecorator

  include GroupConstants
  delegate :id, :name, :description, :escalate_to, :group_type, to: :record

  def initialize(record, options)
    super(record)
    @agent_mapping_ids = options[:agent_mapping_ids]
    @agent_groups_ids = options[:agent_groups_ids]
    @group_type_mapping = options[:group_type_mapping] || Account.current.group_type_mapping
  end

  def to_hash
    User.current.privilege?(:manage_availability) ? to_full_hash : to_restricted_hash
  end

  def to_ocr_hash
    {
      id: record.id,
      name: record.name
    }
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
      group_type: @group_type_mapping[record.group_type],
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }.merge(fetch_additional_hash)
  end

  def to_restricted_hash
     ret_hash={
      id: record.id,
      name: record.name,
      agent_ids: agent_ids,
      group_type: @group_type_mapping[record.group_type],
      assignment_type: assignment_type
      }
      if round_robin_enabled? && assignment_type == ROUND_ROBIN_ASSIGNMENT
        ret_hash.merge!(round_robin_hash) 
      end
    ret_hash
  end

  def round_robin_enabled?
    Account.current.features? :round_robin
  end

  def unassigned_for
    UNASSIGNED_FOR_MAP.key(record.assign_time)
  end

  def agent_ids_from_db
    record.agent_groups.pluck(:user_id)
  end

  def agent_ids_from_loaded_record
    record.agent_groups.map(&:user_id).uniq
  end

  def agent_user_ids
    record.agent_groups.loaded? ? agent_ids_from_loaded_record : agent_ids_from_db
  end

  def agent_ids
    (@agent_mapping_ids || (@agent_groups_ids && @agent_groups_ids[record.id]) || agent_user_ids || []).compact.uniq
  end

  def business_hour_id
    record.business_calendar_id
  end  
  
  def auto_ticket_assign
    to_bool(:ticket_assign_type)
  end

  def business_hour_hash
    business_hour = record.business_calendar
    return business_hour if business_hour.nil?
    result = Hash.new
    result[:id] = business_hour.id
    result[:name] = business_hour.name
    result  
  end

  def assignment_type
    DB_ASSIGNMENT_TYPE_FOR_MAP[record.ticket_assign_type]
  end

  def get_round_robin_type
    rr_type = ROUND_ROBIN if record.ticket_assign_type == 1 && record.capping_limit == 0
    rr_type = LOAD_BASED_ROUND_ROBIN if record.ticket_assign_type == 1 && record.capping_limit != 0
    rr_type = SKILL_BASED_ROUND_ROBIN if record.ticket_assign_type == 2 
    rr_type = LBRR_BY_OMNIROUTE if record.ticket_assign_type == 12
    rr_type
  end

  def allow_agents_to_change_availability
    record.toggle_availability
  end

  def to_private_hash
    result_hash = basic_hash

    if business_hour_hash
     result_hash.merge!({business_hour: business_hour_hash})
    end

    if Account.current.agent_statuses_enabled? || (Account.current.omni_channel_routing_enabled? && assignment_type == OMNI_CHANNEL_ROUTING_ASSIGNMENT)
      result_hash.merge!(allow_agents_to_change_availability: allow_agents_to_change_availability)
    elsif round_robin_enabled? && assignment_type == ROUND_ROBIN_ASSIGNMENT
      result_hash.merge!(round_robin_hash)
    end

    result_hash
  end

  def to_index_hash
    {
      id: record.id,
      name: record.name,
      description: record.description,
      agent_ids: agent_ids
    }
  end

  def freshbots_index_hash
    {
      id: record.id,
      name: record.name,
      description: record.description,
      group_type: @group_type_mapping[record.group_type]
    }
  end

  def round_robin_hash
    rr_type = get_round_robin_type

    rr_hash = {
      round_robin_type: rr_type,
      allow_agents_to_change_availability: allow_agents_to_change_availability
    }

    rr_hash.merge!({capping_limit: record.capping_limit}) if [LOAD_BASED_ROUND_ROBIN, SKILL_BASED_ROUND_ROBIN].include?(rr_type)
    rr_hash
  end

  def basic_hash
  {
    id:record.id,
    name: record.name,
    description: record.description,
    escalate_to: record.escalate_to,
    unassigned_for: unassigned_for,
    agent_ids: agent_ids,
    group_type: @group_type_mapping[record.group_type],
    assignment_type: assignment_type,
    created_at: created_at.try(:utc),
    updated_at: updated_at.try(:utc)
  }
  end

  def fetch_additional_hash
    if Account.current.agent_statuses_enabled? && round_robin_enabled?
      { auto_ticket_assign: auto_ticket_assign, allow_agents_to_change_availability: allow_agents_to_change_availability }
    elsif Account.current.agent_statuses_enabled?
      { allow_agents_to_change_availability: allow_agents_to_change_availability }
    else
      round_robin_enabled? ? { auto_ticket_assign: auto_ticket_assign } : {}
    end
  end
end
