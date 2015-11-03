 class GroupDelegator < SimpleDelegator
   include ActiveModel::Validations

   attr_accessor :error_options, :agent_ids

   validate :valid_agent?, if: -> { escalate_to.present? }
   validate :valid_agent, if: -> { agent_groups.present? }

   private

     def valid_agent?
       invalid_user = get_invalid_user [] << escalate_to
       errors[:escalate_to] << :blank if invalid_user.present?
     end

     def valid_agent
       invalid_users = get_invalid_user agent_groups.map(&:user_id)
       if invalid_users.present?
         errors[:agent_ids] << :invalid_list
         @error_options = { agent_ids: { list: "#{invalid_users.join(', ')}" }  }
       end
     end

     def get_invalid_user(agent_list)
       (agent_list - Account.current.agents_from_cache.map(&:user_id))
     end
 end
