class Helpdesk::Filters::CustomTicketFilter < Wf::Filter
  
  include Search::TicketSearch
  
  attr_accessor :query_hash 
  
  MODEL_NAME = "Helpdesk::Ticket"

  def definition
     @definition ||= begin
      defs = {}
      #default fields
      TicketConstants::DEFAULT_COLUMNS_KEYS_BY_TOKEN.each do |name,cont|
        defs[name.to_sym] = { get_op_list(cont).to_sym => cont  , :name => name, :container => cont,     
        :operator => get_op_list(cont), :options => get_default_choices(name.to_sym) }
      end
      #Custome fields
      Account.current.ticket_fields.custom_dropdown_fields(:include => {:flexifield_def_entry => {:include => :flexifield_picklist_vals } } ).each do |col|
        defs[get_id_from_field(col).to_sym] = {get_op_from_field(col).to_sym => get_container_from_field(col) ,:name => col.label, :container => get_container_from_field(col), :operator => get_op_from_field(col), :options => get_custom_choices(col) }
      end 
      defs
    end
  end
  
  def default_order
    'created_at'
  end
  
  def default_filter
    TicketConstants::DEFAULT_FILTER
  end
  
  def self.deserialize_from_params(params)
    filter = Account.current.ticket_filters.new(params[:wf_model])
    filter.deserialize_from_params(params)
  end
 
  
  def deserialize_from_params(params)   
    @conditions = []
    @match                = :and
    @key                  = params[:wf_key]         || self.id.to_s
    self.model_class_name = params[:wf_model]       if params[:wf_model]
    
    @per_page             = params[:wf_per_page]    || default_per_page
    @page                 = params[:page]           || 1
    @order_type           = params[:wf_order_type]  || default_order_type
    @order                = params[:wf_order]       || default_order
    
    self.id   =  params[:wf_id].to_i  unless params[:wf_id].blank?
    self.name =  params[:filter_name]     unless params[:filter_name].blank?
    
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
    
    action_hash = []
    action_hash = ActiveSupport::JSON.decode params[:data_hash] unless params[:data_hash].blank?
    action_hash = default_filter  if params[:data_hash].blank?
    self.query_hash = action_hash
   
    action_hash.each do |filter|
      add_condition(filter["condition"], filter["operator"].to_sym, filter["value"]) unless filter["value"].blank?
    end

    if params[:wf_submitted] == 'true'
      validate!
    end
    
    return self
  end
  
  def serialize_to_params(merge_params = {})
    params = {}
    params[:wf_type]        = self.class.name
    params[:wf_match]       = match
    params[:wf_model]       = model_class_name
    params[:wf_order]       = order
    params[:wf_order_type]  = order_type
    params[:wf_per_page]    = per_page
    
    
    params[:data_hash] = self.query_hash
    params
  
  end
  
  
  def joins
    ["INNER JOIN flexifields ON flexifields.flexifield_set_id = helpdesk_tickets.id"]
  end      
  
end