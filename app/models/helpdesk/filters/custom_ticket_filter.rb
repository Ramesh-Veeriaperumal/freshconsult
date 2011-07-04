class Helpdesk::Filters::CustomTicketFilter < Wf::Filter

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
  
 
  
  def deserialize_from_params(params)
    @conditions = []
    @match                = params[:wf_match]       || :all
    @key                  = params[:wf_key]         || self.id.to_s
    self.model_class_name = params[:wf_model]       if params[:wf_model]
    
    @per_page             = params[:wf_per_page]    || default_per_page
    @page                 = params[:page]           || 1
    @order_type           = params[:wf_order_type]  || default_order_type
    @order                = params[:wf_order]       || default_order
    
    self.id   =  params[:wf_id].to_i  unless params[:wf_id].blank?
    self.name =  params[:wf_name]     unless params[:wf_name].blank?
    
    @fields = []
    unless params[:wf_export_fields].blank?
      params[:wf_export_fields].split(",").each do |fld|
        @fields << fld.to_sym
      end
    end

    if params[:wf_export_format].blank?
      @format = :html
    else  
      @format = params[:wf_export_format].to_sym
    end
    
    i = 0
    while params["wf_c#{i}"] do
      conditon_key = params["wf_c#{i}"]
      operator_key = params["wf_o#{i}"]
      values = []
      j = 0
      while params["wf_v#{i}_#{j}"] do
        values << params["wf_v#{i}_#{j}"]
        j += 1
      end
      i += 1
      add_condition(conditon_key, operator_key.to_sym, values)
    end

    if params[:wf_submitted] == 'true'
      validate!
    end

    return self
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
      return TicketConstants::TYPE_NAMES_BY_KEY
    end
    
    return []
  end
  
  def joins
    ["INNER JOIN flexifields ON flexifields.flexifield_set_id = helpdesk_tickets.id"]
  end      
  
end