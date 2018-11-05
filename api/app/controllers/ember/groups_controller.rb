module Ember
  class GroupsController < ::ApiGroupsController
    include GroupConstants
    decorate_views

    def index
      super
      response.api_meta = { count: @items_count }
    end

     private
      def validate_params                         
        group_params=api_current_user.privilege?(:admin_tasks) ? PRIVATE_API_FIELDS_WITHOUT_ASSIGNMENT_CONFIG : []
        group_params=Account.current.features?(:round_robin) ? group_params | RR_FIELDS : group_params  
        group_params=Account.current.omni_channel_routing_enabled?  ? group_params | OCR_FIELDS : group_params            
        params[cname].permit(*group_params)        
        group=PrivateApiGroupValidation.new(params[cname],@item)                
        render_errors group.errors, group.error_options unless group.valid?       
      end

      def sanitize_params                     
        reset_attributes if update?
        params[cname][:assignment_type] = ASSIGNMENT_TYPES_SANITIZE[params[cname][:assignment_type]] if params[cname][:assignment_type].present?
        params[cname][:unassigned_for] = UNASSIGNED_FOR_MAP[params[cname][:unassigned_for]] if params[cname][:unassigned_for].present?        
        ParamsHelper.assign_and_clean_params({allow_agents_to_change_availability: :toggle_availability, business_hour_id: :business_calendar_id, unassigned_for: :assign_time },params[cname])
        if params[cname][:assignment_type] == ROUND_ROBIN_ASSIGNMENT || params[cname][:round_robin_type].present?
          params[cname][:round_robin_type] = params[cname][:round_robin_type].nil?  ? params[cname][:assignment_type]: 
          ROUND_ROBIN_TYPE_SANITIZE[params[cname][:round_robin_type]]
          ParamsHelper.assign_and_clean_params({round_robin_type: :ticket_assign_type},params[cname])          
        else
          ParamsHelper.assign_and_clean_params({assignment_type: :ticket_assign_type},params[cname])
        end              
      end       

      def scoper
        return current_account.groups if create?
        return current_account.groups_from_cache if index? && api_current_user.privilege?(:admin_tasks)
        return api_current_user.accessible_groups unless destroy?
        return current_account.groups_from_cache
      end

      def decorator_options
        super({ agent_groups_ids: group_agents_mappings })
      end

      def group_agents_mappings
        agent_groups_ids = Hash.new { |hash, key| hash[key] = [] }
        agents_groups = current_account.agent_groups_from_cache
        agents_groups.each do |ag|
          agent_groups_ids[ag.group_id].push(ag.user_id)
        end
        agent_groups_ids
      end

      def reset_attributes                
        if params[cname]["assignment_type"] == NO_ASSIGNMENT
          @item["capping_limit"]=0, @item["toggle_availability"]=0
        elsif (params[cname]["assignment_type"] == ROUND_ROBIN_ASSIGNMENT && params[cname]["round_robin_type"] == ROUND_ROBIN) || 
          params[cname]["round_robin_type"] == ROUND_ROBIN       
          @item["capping_limit"]=0
        elsif params[cname]["assignment_type"]== OMNI_CHANNEL_ROUTING_ASSIGNMENT
          @item["capping_limit"]=0
        end
      end    

      def load_objects(items = scoper)
        items.sort_by { |x| x.name.downcase }
        @items_count = items.count if private_api?
        @items = items
      end

      def render_success_response
        render 'show', status: 201 
      end 
  end
end
