class GroupDelegator < BaseDelegator
  attr_accessor :agent_ids

  validate :valid_agent?, if: -> { escalate_to.present? }
  validate :valid_agent, if: -> { agent_groups.present? }
  validate :valid_business_calendar?, if: -> {  business_calendar_id.present? }

  private

    def valid_agent?
      invalid_user = invalid_users [] << escalate_to
      errors[:escalate_to] << :"can't be blank" if invalid_user.present?
    end

    def valid_agent
      invalid_users = invalid_users agent_groups.map(&:user_id)
      if invalid_users.present?
        errors[:agent_ids] << :invalid_list
        @error_options = { agent_ids: { list: invalid_users.join(', ').to_s } }
      end
    end

    def invalid_users(agent_list)
      (agent_list - Account.current.agents_details_from_cache.map(&:id))
    end

    def valid_business_calendar?       
      if !Account.current.business_calendar.find_by_id(business_calendar_id)
        errors[:business_hour_id] << :invalid_values
        @error_options= { business_hour_id: {fields: business_calendar_id}}
      end
    end 

end
