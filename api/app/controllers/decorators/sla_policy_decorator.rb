class SlaPolicyDecorator < ApiDecorator
  def initialize(record, options = {})
    super(record, options)
  end

  def pluralize_sla_target
    record.sla_details.inject({}) do |return_hash, (key, val)|
      return_hash["priority_#{key[:priority]}"] = sla_target_hash(key)
      return_hash
    end
  end

  def pluralize_conditions
    return_hash = {}
    record.conditions.each do |key, value|
      # temporary hack for UI to handle company names instead of IDs
      if key == 'company_id' && private_api?
        company_names = Account.current.companies.where('id IN (?)', value).pluck('name')
        return_hash[key.to_s.pluralize] = company_names
      else
        return_hash[key.to_s.pluralize] = value
      end
    end if record.conditions
    return_hash
  end

  def pluralize_escalations
    record.escalations.inject({}) do |return_hash, (key, val)|
      if SlaPolicyConstants::ESCALATION_TYPES_EXCEPT_RESOLUTION.include?(key)
        return_hash[key] = response_hash(val['1']) unless ['reminder_next_response', 'next_response'].include?(key) && !Account.current.next_response_sla_enabled?
      else
        return_hash[key] = resolution_hash(val)
      end
      return_hash
    end
  end

  def resolution_hash(input_hash)
    return {} if input_hash.blank?

    input_hash.inject({}) do |_hash, (key, value)|
      _hash["level_#{key}"] = response_hash(value)
      _hash
    end
  end

  def response_hash(input_hash)
    return {} if input_hash.blank?

    {
      escalation_time: input_hash[:time],
      agent_ids: input_hash[:agents_id]
    }
  end

  def sla_target_hash(input_hash)
    hash = {}
    if private_api?
      hash[:first_response_time] = input_hash.sla_target_time[:first_response_time]
      hash[:resolution_due_time] = input_hash.sla_target_time[:resolution_due_time]
      hash[:every_response_time] = input_hash.sla_target_time[:every_response_time] if Account.current.next_response_sla_enabled?
    else
      hash[:respond_within] = input_hash.response_time
      hash[:resolve_within] = input_hash.resolution_time
      hash[:next_respond_within] = input_hash.next_response_time if Account.current.next_response_sla_enabled?
    end
    hash[:business_hours] = !input_hash.override_bhrs
    hash[:escalation_enabled] = input_hash.escalation_enabled
    hash
  end

  def private_hash
    {
      id: record.id,
      name: record.name
    }
  end

  def to_hash
    response_hash = {
      id: record.id,
      name: record.name,
      description: record.description,
      active: record.active,
      sla_target: pluralize_sla_target,
      applicable_to: pluralize_conditions,
      is_default: record.is_default,
      position: visual_position,
      created_at: record.created_at.try(:utc),
      updated_at: record.updated_at.try(:utc)
    }
    response_hash[:escalation] = pluralize_escalations if Account.current.sla_management_enabled?
    response_hash
  end

  def visual_position
    private_api? ? sla_rules_position.index(record.position) + 1 : record.position
  end

  def sla_rules_position
    @sla_rules_position ||= current_account.sla_policies_reorder.pluck(:position)
  end
end
