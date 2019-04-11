module AuditLog::AuditLogExportHelper
  private

    def filter_set_params(filter, export_filter_set_params)
      type = []
      filter.each do |filter_sets|
        filter_sets.each do |filter_set|
          filter_sets_key = filter_set.to_sym if filter_set.include? 'filter_set'
          filter_set_value = filter[filter_sets_key] # entity_assign
          next if filter_set_value.blank?

          entity_ids = filter_set_value[:ids].presence # rule_id
          entity_ids.map!(&:to_s) unless entity_ids.nil?
          if filter_set_value[:entity].count == 1
            if (AuditLogConstants::AUTOMATION_TYPES.include? filter_set_value[:entity][0]) && !entity_ids.nil?
              entity_name = AuditLogConstants::ENTITY_HASH[filter_set_value[:entity][0]]
              entity_name = VAConfig::RULES_BY_ID[entity_name.to_i].to_s << '_id'
              export_filter_set_params[entity_name] = entity_ids
              params[:condition].sub!(filter_sets_key.to_s, entity_name) if params[:condition].include? filter_sets_key.to_s
            elsif filter_set_value[:entity][0] == 'agent' && !entity_ids.nil?
              entity_name = 'agent_id'
              export_filter_set_params[entity_name] = entity_ids
              params[:condition].sub!(filter_sets_key.to_s, entity_name) if params[:condition].include? filter_sets_key.to_s
            else
              type_value = construct_type_array(filter_set_value)
              type.push(type_value) unless type.nil?
              update_condition(filter_sets_key, params)
            end
          else
            filter_set_value[:entity].each do |entity|
              if AuditLogConstants::AUTOMATION_TYPES.include? entity
                entity_temp = replace_type_values(entity)
                type.push(entity_temp)
              else
                type.push(entity)
              end
            end
            update_condition(filter_sets_key, params)
          end
          export_filter_set_params[:type] = type unless type.nil?
        end
      end
      export_filter_set_params
    end

    def construct_type_array(filter_set_value)
      type = replace_type_values(filter_set_value[:entity][0])
      type
    end

    def update_condition(filter_sets_key, _entity)
      condition = params[:condition]
      condition = condition.split(' ')
      if condition.include? filter_sets_key.to_s
        ind = condition.index(filter_sets_key.to_s)
        condition[ind] = 'type'
      end
      params[:condition] = condition.join(' ')
    end

    def replace_type_values(value)
      if AuditLogConstants::ENTITY_HASH.include? value
        id = AuditLogConstants::ENTITY_HASH[value]
        rule_name = VAConfig::RULES_BY_ID[id.to_i].to_s
      end
      value = rule_name unless rule_name.nil?
      value
    end

    def fetch_zone
      zone = User.current.time_zone
      zone = Time.now.in_time_zone(zone).strftime('%:z')
      zone
    end
end
