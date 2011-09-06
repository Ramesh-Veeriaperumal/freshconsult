module Search::TicketSearch
  
  def show_options
     @show_options ||= begin
      defs = []
      i = 0
      #default fields
      TicketConstants::DEFAULT_COLUMNS_KEYS_BY_TOKEN.each do |name,cont|
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
      defs
    end
  end
  
  
  def get_id_from_field(tf)
    "flexifield.#{tf.flexifield_def_entry.flexifield_name}"
  end
  
  def get_container_from_field(tf)
    tf.field_type.gsub('custom_', '')
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
    #Hash[*choice_array.collect { |v| [v, v]}.flatten]
  end
  
   def get_default_choices(criteria_key)
    if criteria_key == :status
      return TicketConstants::STATUS_NAMES_BY_KEY
    end
    
    if criteria_key == :ticket_type
      return Account.current.ticket_type_values.collect { |tt| [tt.value, tt.value] }
    end
    
    if criteria_key == :source
      return TicketConstants::SOURCE_NAMES_BY_KEY
    end
    
    if criteria_key == :priority
      return TicketConstants::PRIORITY_NAMES_BY_KEY
    end
    
    if criteria_key == :responder_id
      agents =  Account.current.users.technicians.collect { |au| [au.id, au.name] }
      return agents
    end
    
    if criteria_key == :group_id
      groups  = Account.current.groups.find(:all, :order=>'name' ).collect { |g| [g.id, g.name]}
      return groups
    end
      
   
    
    return []
  end
  
end