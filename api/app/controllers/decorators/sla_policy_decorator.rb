class SlaPolicyDecorator < ApiDecorator
  class << self
    def pluralize_conditions(input_hash)
      return_hash = {}
      input_hash.each { |key, value| return_hash[key.to_s.pluralize] = value } if input_hash
      return_hash
    end

    def pluralize_sla_target(input_hash)
      input_hash.inject({}) do |return_hash,(key,val)|
        return_hash["priority_#{key[:priority]}"] = sla_target_hash(key)
        return_hash
      end
    end

    def pluralize_escalations(input_hash)
      input_hash.inject({}) do |return_hash,(key,val)|
        if SlaPolicyConstants::ESCALATION_TYPES_EXCEPT_RESOLUTION.include?(key)
          return_hash[key] = response_hash(val["1"])
        else
          return_hash[key] = resolution_hash(val)
        end
        return_hash
      end
    end

    def resolution_hash(input_hash)
      return {} if input_hash.blank?
      input_hash.inject({}) do |_hash, (key,value)| 
        _hash["level_#{key}"] =  response_hash(value)
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
      hash = {
        respond_within:       input_hash.response_time,
        resolve_within:       input_hash.resolution_time, 
        business_hours:       !input_hash.override_bhrs, 
        escalation_enabled:   input_hash.escalation_enabled
      }
      Account.current.next_response_sla_enabled? ? hash.merge!(next_respond_within: input_hash.next_response_time) : hash
    end

  end

  def initialize(record)
    super(record)
  end

  def private_hash
    {
      id: record.id,
      name: record.name
    }
  end

  def to_hash
    {
      id: record.id,
      name: record.name,
      description: record.description,
      active: record.active,
      sla_target: self.class.pluralize_sla_target(record.sla_details),
      applicable_to: self.class.pluralize_conditions(record.conditions),
      escalation: self.class.pluralize_escalations(record.escalations),
      is_default: record.is_default,
      position: record.position,
      created_at: record.created_at.try(:utc),
      updated_at: record.updated_at.try(:utc)
    }
  end

end   

