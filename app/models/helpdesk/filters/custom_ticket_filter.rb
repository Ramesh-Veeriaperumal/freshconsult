class CustomTicketFilter < Wf::Filter
   
   def definition
     @definition ||= begin
      defs = {}
      model_columns.each do |col|
        defs[col.name.to_sym] = default_condition_definition_for(col.name, col.sql_type) if TicketConstants::DEFAULT_COLUMNS_KEYS_BY_TOKEN.keys.include?(col.name.to_sym)
      end 
      defs
    end
  end
  
  def value_options_for(criteria_key)
    if criteria_key == :status
      return TicketConstants::STATUS_NAMES_BY_KEY.keys
    end
    
    if criteria_key == :ticket_type
      return TicketConstants::TYPE_NAMES_BY_KEY.keys
    end

    return []
  end
  
  def container_by_sql_type(type,name=nil)
    raise Wf::FilterException.new("Unsupported data type #{type}") unless Wf::Config.data_types[type]
    return Wf::Config.data_types[:helpdesk_tickets][get_tkt_data_type(name)]  
  end
  
  def get_tkt_data_type(name)    
    TicketConstants::DEFAULT_COLUMNS_KEYS_BY_TOKEN[name.to_sym] 
  end
  
  def default_condition_definition_for(name, sql_data_type)
    type = sql_data_type.split(" ").first.split("(").first.downcase
    
    containers = container_by_sql_type(type,name)
    operators = {}
    containers.each do |c|
      raise Wf::FilterException.new("Unsupported container implementation for #{c}") unless Wf::Config.containers[c]
      container_klass = Wf::Config.containers[c].constantize
      container_klass.operators.each do |o|
        operators[o] = c
      end
    end
    
    if name == "id"
      operators[:is_filtered_by] = :filter_list 
    elsif "_id" == name[-3..-1]
      begin
        name[0..-4].camelcase.constantize
        operators[:is_filtered_by] = :filter_list 
      rescue  
      end
    end
    
    operators
  end
  
end