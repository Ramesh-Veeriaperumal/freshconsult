module HelpdeskReports
  module Export
    module FieldsHelper
      
      attr_accessor :ticket
      
      def fields_hash(ticket)
        self.ticket = ticket
        [default_field_hash, dropdown_fields_to_picklist_value_hash, 
          nested_fields_to_picklist_value_hash ].reduce(&:merge)
      end
      
      private
      
        def default_field_hash 
          {
            "#{I18n.t('export_data.fields.display_id')}"     => ticket.display_id,
            "#{I18n.t('export_data.fields.subject')}"        => ticket.subject,
            "#{I18n.t('export_data.fields.requester_name')}" => ticket.requester_name,
            "#{I18n.t('export_data.fields.status')}"         => ticket.status_name,
            "#{I18n.t('export_data.fields.priority')}"       => ticket.priority_name,
            "#{I18n.t('export_data.fields.source')}"         => ticket.source_name,
            "#{I18n.t('export_data.fields.type')}"           => ticket.ticket_type,
            "#{I18n.t('export_data.fields.agent')}"          => ticket.responder_name,
            "#{I18n.t('export_data.fields.group')}"          => ticket.group_name,
            "#{I18n.t('export_data.fields.product')}"        => ticket.product_name,
            "#{I18n.t('export_data.fields.company')}"        => ticket.company_name,
            "#{I18n.t('export_data.fields.tags')}"           => ticket.ticket_tags
          }
        end
            
        def dropdown_fields
          Account.current.custom_dropdown_fields_from_cache
        end 

        def nested_fields 
          Account.current.nested_fields_from_cache
        end
        
        def dropdown_or_level_1_picklist(field)
          cf_hash = ticket.custom_field.select {|k,v| k == field.name} 
          field.picklist_values.detect {|r| r.value == cf_hash[field.name]} if cf_hash[field.name]
        end 
        
        def dropdown_fields_to_picklist_value_hash    
          dropdown_fields_hash = dropdown_fields.inject({}) do |hash, dd_field|
            picklist = dropdown_or_level_1_picklist(dd_field)
            hash.merge!(dd_field.label => (picklist ? picklist.value : nil))
            hash
          end
        end
        
        def nested_fields_to_picklist_value_hash
          nested_field_hash = {}
          
          nested_fields.each do |n_field|
            
            next unless n_field.flexifield_def_entry
            
            level_1_picklist = dropdown_or_level_1_picklist(n_field)
            nested_field_hash[n_field.label] = (level_1_picklist ? level_1_picklist.value : nil)
            child_levels      = n_field.nested_ticket_fields
            child_level_names = child_levels.map(&:name)
            
            next if child_level_names.empty?
            
            ticket_level_2_name_to_value = ticket.custom_field.select {|k,v| k == child_level_names.first }
            ticket_level_3_name_to_value = ticket.custom_field.select {|k,v| k == child_level_names.last  }
            
            next if ticket_level_2_name_to_value.empty? || ticket_level_3_name_to_value.empty?
            
            # Level 2
            if level_1_picklist
              level_2_picklist = level_1_picklist.sub_picklist_values.detect { |sub_pick| sub_pick.value == ticket_level_2_name_to_value.values.first}
              nested_field_hash[child_levels.first.label] = (level_2_picklist ? level_2_picklist.value : nil)
            end
            
            # Level 3
            if level_2_picklist
              level_3_picklist = level_2_picklist.sub_picklist_values.detect { |sub_pick| sub_pick.value == ticket_level_3_name_to_value.values.first}
              nested_field_hash[child_levels.second.label] = (level_3_picklist ? level_3_picklist.value : nil)
            end
            
          end
          nested_field_hash
        end
      
    end
  end
end