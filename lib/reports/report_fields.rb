module Reports::ReportFields
  
  def show_options ( column_order, columns_keys_by_token, columns_option)
    @show_fields = {}
    @show_options ||= begin
      defs = []
      i = 0
      #default fields
      column_order.each do |name|
        cont = columns_keys_by_token[name]
        defs.insert(i,{ get_op_list(cont).to_sym => cont  , :condition => name , 
        :name => columns_option[name], :container => cont, :operator => get_op_list(cont), 
        :options => get_default_choices(name), :value => "", :f_type => :default  })
        i = i+ 1
      end
      #Custom fields
      current_account.custom_dropdown_fields_from_cache.each do |col|
        @show_fields[get_id_from_field(col)] = col.label
        defs.insert(i,{get_op_from_field(col).to_sym => get_container_from_field(col),
        :condition => get_id_from_field(col).to_sym ,:name => col.label , 
        :container => get_container_from_field(col),     
        :operator => get_op_from_field(col), :options => get_custom_choices(col), :value => "" })
        i = i+ 1     
      end 

      ## added to handle the group by query for nested fields.. 
      nested_fields_cols = {}
      current_account.nested_fields_from_cache.each do |col|
        ff_name = get_id_from_field(col)
        @show_fields[ff_name] = col.label
        nested_fields = []
        nested_fields_cols.store(ff_name,[].push(ff_name))
        
        col.nested_ticket_fields(:include => :flexifield_def_entry).each do |nested_col|
          nested_fields_cols.store(ff_name,
            nested_fields_cols.fetch(ff_name).push(get_id_from_field(nested_col)))
          nested_fields.push({get_op_list('dropdown').to_sym => 'dropdown',
          :condition => get_id_from_field(nested_col).to_sym ,:name => nested_col.label , 
          :container => 'dropdown', :operator => get_op_list('dropdown'), :options => [], 
          :value => "" , :field_type => "nested_field"}) 
        end

        defs.insert(i,{get_op_from_field(col).to_sym => get_container_from_field(col),
          :condition => ff_name.to_sym, :name => col.label , 
          :container => get_container_from_field(col), :operator => get_op_from_field(col), 
          :options => col.nested_choices, :value => "" , :field_type => "nested_field", 
          :field_id => col.id, :nested_fields => nested_fields})
        i = i+ 1
      end
      @ticket_nested_fields = nested_fields_cols
      defs
    end
  end
  
  
  def get_id_from_field(tf)
    "#{tf.flexifield_def_entry.flexifield_name}"
  end
  
  def get_container_from_field(tf)
    tf.field_type.gsub('custom_', '').gsub('nested_field','dropdown')
  end
  
  def get_op_from_field(tf)
    get_op_list(get_container_from_field(tf))    
  end
  
  def get_op_list(name)
    containers = Wf::Config.data_types[:helpdesk_tickets][name]
    container_klass = Wf::Config.containers[containers.first].constantize
    container_klass.operators.first   
  end
  
  def get_custom_choices(tf)
    choice_array = tf.choices
  end

  def get_default_choices(criteria_key)
    case criteria_key
      when :status
        return Helpdesk::TicketStatus.status_names_from_cache(current_account)
      when :ticket_type
        return current_account.ticket_types_from_cache.collect { |tt| [tt.value, tt.value] }
      when :source
        return TicketConstants.source_list.sort
      when :priority
        return TicketConstants.priority_list.sort
      when :responder_id
        agents = []
        agents.concat(current_account.agents_from_cache.collect { |au| [au.user.id, au.user.name] })
        return agents
      when :group_id
        groups = []
        groups.concat(current_account.groups_from_cache.collect { |g| [g.id, g.name]})
        return groups
      when :product_id
        current_account.products.collect {|p| [p.id, p.name]}
      when :customer_id
        return current_account.customers_from_cache.collect { |au| [au.id, au.name] }
      else
        return []
    end
  end
  
end