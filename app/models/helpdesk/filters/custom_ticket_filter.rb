class CustomTicketFilter < Wf::Filter
#   
#  def initialize(model_class,account)
#    super(model_class)
#    self.model_class_name = model_class.to_s
#    @current_account = account
#  end
#  
#  def definition
#    show_definition(@current_account)
#  end
   
  def definition
     @definition ||= begin
      defs = {}
      #default fields
      TicketConstants::DEFAULT_COLUMNS_OPTIONS.each do |name,cont|
        defs[name.to_sym] = { get_op_list(cont).to_sym => cont  , :name => name, :container => cont,     
        :operator => get_op_list(cont), :options => get_default_choices(name.to_sym) }
      end
      #Custome fields
      Account.current.ticket_fields.custom_fields(:include => {:flexifield_def_entry => {:include => :flexifield_picklist_vals } } ).each do |col|
        defs[get_id_from_field(col).to_sym] = {get_op_from_field(col).to_sym => get_container_from_field(col) ,:name => col.label , :container => get_container_from_field(col),     
        :operator => get_op_from_field(col), :options => get_custom_choices(col) }
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
    choice_array = tf.flexifield_def_entry.flexifield_picklist_vals
    Hash[*choice_array.collect { |v| [v, v]}.flatten]
  end
  
   def get_default_choices(criteria_key)
    if criteria_key == :status
      return TicketConstants::STATUS_NAMES_BY_KEY
    end
    
    if criteria_key == :ticket_type
      return TicketConstants::TYPE_NAMES_BY_KEY
    end
    
    return []
  end
  
  def joins
    ["INNER JOIN flexifields ON flexifields.flexifield_set_id = helpdesk_tickets.id"]
  end      
  
end