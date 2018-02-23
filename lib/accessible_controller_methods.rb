module AccessibleControllerMethods
  def create_helpdesk_accessible(item,model_name)
    return if item.helpdesk_accessible
      visible_type_id,visible_type_str  = map_new_visible_type(model_name)
      accessible = item.create_helpdesk_accessible(:access_type => visible_type_id)
      if visible_type_id != Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
        accessible_ids = [*params[model_name][:visibility]["#{visible_type_str}_id"]]
        accessible.safe_send("create_#{visible_type_str}_accesses",accessible_ids)
      end
    end

    def update_helpdesk_accessible(item,model_name)
      if item.helpdesk_accessible.nil?
        create_helpdesk_accessible(item,model_name) 
      else
        new_visible_type_id,new_visible_type_str = map_new_visible_type(model_name)
        old_visible_type_id = item.helpdesk_accessible.access_type
        old_visible_type_str = Helpdesk::Access::ACCESS_TYPES_KEYS[old_visible_type_id]
        accessible_ids = [*params[model_name][:visibility]["#{new_visible_type_str}_id"]] if new_visible_type_id != Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
        item.helpdesk_accessible.update_attributes(:access_type =>  new_visible_type_id)
        item.helpdesk_accessible.safe_send("update_#{old_visible_type_str}_access_type_to_#{new_visible_type_str}",accessible_ids)
      end
    end

    def map_new_visible_type(model_name) 
      case params[model_name][:visibility][:visibility].to_i 
      when Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents]
        new_visible_type_id = Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
      when Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
        new_visible_type_id = Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
      when Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
        new_visible_type_id = Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
      end
      return new_visible_type_id, Helpdesk::Access::ACCESS_TYPES_KEYS[new_visible_type_id]
    end
  end
