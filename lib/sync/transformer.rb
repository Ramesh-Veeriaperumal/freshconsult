module Sync
  class Transformer

    attr_accessor :master_account_id, :mapping_table, :account

    TRANSFORMATIONS = {
        "Helpdesk::TicketField"       => ["name"],
        "Helpdesk::NestedTicketField" => ["name"],
        "FlexifieldDef"               => ["name"],
        "FlexifieldDefEntry"          => ["flexifield_alias"],
        "VaRule"                      => ["filter_data", "action_data"],
        "Helpdesk::SlaPolicy"         => ["escalations", "conditions"],
        "Helpdesk::TicketTemplate"    => ["template_data"]
      }

    def initialize(master_account_id, account = Account.current)
      @master_account_id = master_account_id
      @account           = account
      @mapping_table     = {}
    end

    def available?(model, column)
      (TRANSFORMATIONS[model.to_s] || []).include?(column)
    end

    def transform_helpdesk_ticket_field_name(data, mapping_table)
      change_custom_field_name(data)
    end

    def transform_flexifield_def_name(data, mapping_table)
      change_custom_field_name(data)
    end

    def transform_helpdesk_nested_ticket_field_name(data, mapping_table)
      change_custom_field_name(data)
    end

    def transform_flexifield_def_entry_flexifield_alias(data, mapping_table)
      change_custom_field_name(data)
    end

    def transform_va_rule_filter_data(data, mapping_table)
      @mapping_table = mapping_table
      name_mappings  = {
        "responder_id" => "User",
        "group_id"     => "Group",
        "tag_ids"      => "Helpdesk::Tag",
        "product_id"   => "Product"
      }
      iterator = if data.is_a? Hash  
        data[:conditions] || [] 
      else
        data
      end

      iterator.each do |it|
        it.symbolize_keys!
        if it[:nested_rules].present?
          it[:name] = apply_custom_field_name_mapping(it[:name], get_mapping_data("Helpdesk::TicketField", "name"))
          it[:nested_rules].each do |nested_rule|
            nested_rule[:name] = apply_custom_field_name_mapping(nested_rule[:name], get_mapping_data("Helpdesk::NestedTicketField", "name"))
          end
        elsif name_mappings.keys.include?(it[:name])
          it[:value] = apply_id_mapping(it[:value], get_mapping_data(name_mappings[it[:name]]))
        elsif it[:name] == "created_at" && it[:business_hours_id].present?
          it[:business_hours_id]  = apply_id_mapping(it[:business_hours_id], get_mapping_data("BusinessCalendar"))
        else
          it[:name] = apply_custom_field_name_mapping(it[:name], get_mapping_data("FlexifieldDefEntry", "flexifield_alias"))
        end
      end

      if data.is_a? Hash
        if data[:performer].present? && data[:performer]["members"].present?
          data[:performer]["members"] = apply_id_mapping(data[:performer]["members"], get_mapping_data("User"))
        end
        iterator = data[:events]
        iterator.each do |it|
          it.symbolize_keys!
          if name_mappings.keys.include?(it[:name])
            [:from , :to].each do |value_key|
              it[value_key] = apply_id_mapping(it[value_key], get_mapping_data(name_mappings[it[:name]]))
            end              
          end
        end       
      end
      data
    end

    def transform_va_rule_action_data(data, mapping_table)
      @mapping_table = mapping_table
      iterator = data
      name_mappings = {
        "responder_id"        => "User",
        "group_id"            => "Group",
        "add_watcher"         => "User",
        "send_email_to_group" => "Group",
        "send_email_to_agent" => "User",
        "internal_group_id"   => "Group",
        "internal_agent_id"   => "User",
        "product_id"          => "Product"
      }
      iterator.each do |it|
        it.symbolize_keys!
        if it[:nested_rules].present?
          it[:category_name] = apply_custom_field_name_mapping(it[:category_name], get_mapping_data("Helpdesk::TicketField", "name"))
          it[:nested_rules].each do |nested_rule|
            nested_rule[:name] = apply_custom_field_name_mapping(nested_rule[:name], get_mapping_data("Helpdesk::NestedTicketField", "name"))
          end 
        elsif name_mappings.keys.include?(it[:name])
          value_key     = ["send_email_to_group", "send_email_to_agent"].include?(it[:name]) ? :email_to : :value
          it[value_key] = apply_id_mapping(it[value_key], get_mapping_data(name_mappings[it[:name]]))         
        else
          it[:name] = apply_custom_field_name_mapping(it[:name], get_mapping_data("FlexifieldDefEntry", "flexifield_alias"))
        end
      end
      data
    end

    def transform_helpdesk_sla_policy_escalations(data, mapping_table)
      @mapping_table = mapping_table
      ["reminder_response", "reminder_resolution", "response", "resolution"].each do |iterator|
        next unless data[iterator].present?
        data[iterator].each do |k,v|
          v["agents_id"] = apply_id_mapping(v["agents_id"], get_mapping_data("User"))
          data[iterator][k] = v
        end
      end
      data
    end

    def transform_helpdesk_sla_policy_conditions(data, mapping_table)
      key_model_mapping = {
        "group_id" => "Group",
        "product_id" => "Product"
      }
      @mapping_table = mapping_table
      key_model_mapping.each do |key, model|    
        if data[key].present?
          data[key] = apply_id_mapping(data[key], get_mapping_data(model))
        end
      end
      data      
    end

    def transform_helpdesk_ticket_template_template_data(data, mapping_table)
      @mapping_table   = mapping_table
      ff_alias_mapping = get_mapping_data("FlexifieldDefEntry", "flexifield_alias")
      ticket_field_mapping      = get_mapping_data("Helpdesk::TicketField", "name")
      nested_field_name_mapping = get_mapping_data("Helpdesk::NestedTicketField", "name")
      data = Hash[data.map { |k, v| [ff_alias_mapping[k]|| ticket_field_mapping[k]|| nested_field_name_mapping[k] || k, v] }]
      key_model_mapping = {
        "responder_id" => "User",
        "product_id"   => "Product",
        "group_id"     => "Group" 
      }
      key_model_mapping.each do |key, model|
        if data[key].present?
          data[key] = apply_id_mapping(data[key], get_mapping_data(model)) 
        end
      end
      ActionController::Parameters.new(data)
    end

    private

      def change_custom_field_name(data)
        if data =~ /(.*)_#{master_account_id}/
          data = "#{$1}_#{account.id}"
        end
        data       
      end

      def apply_custom_field_name_mapping(name_field, mapping_info)
        if name_field.present? && mapping_info[name_field.to_s].present?
          mapping_info[name_field.to_s] 
        else
          name_field
        end
      end

      def apply_id_mapping(value, mapping_info)
        if value.is_a? Array
          value.map { |val| (val.present? && mapping_info[val.to_i].present?) ? mapping_info[val.to_i].to_s : val}
        else
          value.present? && mapping_info[value.to_i].present? ? mapping_info[value.to_i].to_s : value
        end
      end

      def get_mapping_data(model, mapped_column = :id)
        return {} unless mapping_table[model.to_s].present?
        mapping_table[model.to_s][mapped_column] || {}
      end
  end
end