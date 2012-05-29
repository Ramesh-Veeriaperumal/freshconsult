module Search::TicketSearch
  
  def show_options
     @show_options ||= begin
      defs = []
      i = 0
      #default fields
      TicketConstants::DEFAULT_COLUMNS_ORDER.each do |name|
        cont = TicketConstants::DEFAULT_COLUMNS_KEYS_BY_TOKEN[name]
        defs.insert(i,{ get_op_list(cont).to_sym => cont  , :condition => name , :name => TicketConstants::DEFAULT_COLUMNS_OPTIONS[name], :container => cont,     
        :operator => get_op_list(cont), :options => get_default_choices(name), :value => "" })
        i = i+ 1
      end
      #Custom fields
      Account.current.ticket_fields.custom_dropdown_fields(:include => {:flexifield_def_entry => {:include => :flexifield_picklist_vals } } ).each do |col|
        defs.insert(i,{get_op_from_field(col).to_sym => get_container_from_field(col),:condition => get_id_from_field(col).to_sym ,:name => col.label , :container => get_container_from_field(col),     
        :operator => get_op_from_field(col), :options => get_custom_choices(col), :value => "" })
        i = i+ 1     
      end 

      Account.current.ticket_fields.nested_fields(:include => {:flexifield_def_entry => {:include => :flexifield_picklist_vals } } ).each do |col|
        nested_fields = []

        col.nested_ticket_fields(:include => :flexifield_def_entry).each do |nested_col|
          nested_fields.push({get_op_list('dropdown').to_sym => 'dropdown',:condition => get_id_from_field(nested_col).to_sym ,:name => nested_col.label , :container => 'dropdown',     
          :operator => get_op_list('dropdown'), :options => [], :value => "" , :field_type => "nested_field"})     
        end

        defs.insert(i,{get_op_from_field(col).to_sym => get_container_from_field(col),:condition => get_id_from_field(col).to_sym, 
          :name => col.label , :container => get_container_from_field(col), :operator => get_op_from_field(col), 
          :options => col.nested_choices, :value => "" , :field_type => "nested_field", :field_id => col.id, :nested_fields => nested_fields})
        i = i+ 1
      end

      defs
    end
  end
  
  
  def get_id_from_field(tf)
    "flexifields.#{tf.flexifield_def_entry.flexifield_name}"
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
    if criteria_key == :status
      return Helpdesk::TicketStatus::status_names_by_key(Account.current).sort
    end
    
    if criteria_key == :ticket_type
      return Account.current.ticket_type_values.collect { |tt| [tt.value, tt.value] }
    end
    
    if criteria_key == :source
      return TicketConstants::SOURCE_NAMES_BY_KEY.sort
    end
    
    if criteria_key == :priority
      return TicketConstants::PRIORITY_NAMES_BY_KEY.sort
    end
    
    if criteria_key == :responder_id
      agents = []
      agents.push([0, "Me" ])
      agents.concat(Account.current.agents(:include => :user).collect { |au| [au.user.id, au.user.name] })
      agents.push([-1, "Unassigned" ])
      return agents
    end
    
    if criteria_key == :group_id
      groups = []
      groups.push([0, "My Groups" ])
      groups.concat(Account.current.groups.find(:all, :order=>'name' ).collect { |g| [g.id, g.name]})
      return groups
    end
    
    if criteria_key == :due_by
       return TicketConstants::DUE_BY_TYPES_NAMES_BY_KEY
    end
    
     if criteria_key == "helpdesk_tags.name"
       return Account.current.tags.collect { |au| [au.name, au.name] }
    end
      
   if criteria_key == "users.customer_id"
       return Account.current.customers.collect { |au| [au.id, au.name] }
    end
    
    return []
  end
  
end