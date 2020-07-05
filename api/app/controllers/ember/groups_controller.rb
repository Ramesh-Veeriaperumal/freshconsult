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
        group_params = [] unless api_current_user.privilege?(:admin_tasks)
        group_params = if current_account.agent_statuses_enabled? && !service_group?
                         update? ? UPDATE_PRIVATE_API_FIELDS_WITH_STATUS_TOGGLE_WITHOUT_ASSIGNMENT_CONFIG : PRIVATE_API_FIELDS_WITH_STATUS_TOGGLE_WITHOUT_ASSIGNMENT_CONFIG
                       else
                         update? ? UPDATE_PRIVATE_API_FIELDS_WITHOUT_ASSIGNMENT_CONFIG : PRIVATE_API_FIELDS_WITHOUT_ASSIGNMENT_CONFIG
                       end
        group_params=Account.current.features?(:round_robin) ? group_params | RR_FIELDS : group_params  
        group_params=Account.current.omni_channel_routing_enabled?  ? group_params | OCR_FIELDS : group_params            
        params[cname].permit(*group_params)        
        group=PrivateApiGroupValidation.new(params[cname],@item) 
        valid = update? ? group.valid? : group.valid?(:create)               
        render_errors group.errors, group.error_options unless valid     
      end

      def sanitize_params
        if params[cname][:group_type].present?
          group_type_id = GroupType.group_type_id(params[cname][:group_type])
          params[cname][:group_type] = group_type_id
        end                     
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
        return accessible_groups if !api_current_user.privilege?(:admin_tasks)
        return current_account.groups.support_agent_groups if params[:group_type].nil? || (params[:group_type].present? && params[:group_type] == GroupConstants::SUPPORT_GROUP_NAME)
        return current_account.groups.field_agent_groups if params[:group_type].present? && params[:group_type] == GroupConstants::FIELD_GROUP_NAME
      end

      def accessible_groups     
        group_ids_hash = current_account.agent_groups_from_cache.each_with_object ({}) do |ar,hash|
            hash[ar.group_id]=true if ar.user_id==api_current_user.id 
        end   
        current_account.groups_from_cache.select { |ar| group_ids_hash[ar.id] }   
      end

      def decorator_options
        super({
          agent_groups_ids: current_account.write_access_agent_groups_hash_from_cache,
          group_type_mapping: current_account.group_type_mapping
        })
      end

      def reset_attributes                
        if params[cname]["assignment_type"] == NO_ASSIGNMENT
          @item["capping_limit"]=0, @item["toggle_availability"]=0
        elsif [ROUND_ROBIN, LBRR_BY_OMNIROUTE].include?(params[cname]["round_robin_type"])
          @item["capping_limit"]=0
        elsif params[cname]["assignment_type"]== OMNI_CHANNEL_ROUTING_ASSIGNMENT
          @item["capping_limit"]=0
        end
      end    

      def load_objects(items = scoper)
        @items_count = items.count if private_api?
        @items = paginate_items(items)
      end

      def render_success_response
        render 'show', status: 201 
      end

      def service_group?
        (params[:group].present? && params[:group][:group_type] == FIELD_GROUP_NAME) ||
          (@item.present? && @item.group_type == 2)
      end
  end
end
