module VAConfig
  #  def self.prepare(params) 
  #    if params.is_a?(Hash)
  #      params.symbolize_keys!
  #      params.each { |k, v| params[k] = self.prepare(v) }
  #    end
  #    
  #    return params 
  #  end
  
  BUSINESS_RULE = 1
  SCENARIO_AUTOMATION = 2
  SUPERVISOR_RULE = 3
  OBSERVER_RULE = 4
  APP_BUSINESS_RULE = 11
  INSTALLED_APP_BUSINESS_RULE = 12

  def self.handler(field, account, handler_type = :handler)
    field_type = DEFAULT_FIELDS[field]
    if field_type.nil?
      if account.flexifield_def_entries.event_fields.map(&:flexifield_name).include? field.to_s
        field = (account.flexifield_def_entries.find_by_flexifield_name field.to_s).flexifield_alias
      end
      field_type = check_for_custom_field field, account, handler_type
    end

    RAILS_DEFAULT_LOGGER.debug " The field is : #{field} field_type is : #{field_type}"
    HANDLERS[field_type[handler_type].to_sym]
  end
  
  def self.check_for_custom_field(field, account, handler_type)
    t_field = account.ticket_fields.find_by_name field.to_s
    t_field ? Helpdesk::TicketField::FIELD_CLASS[t_field.field_type.to_sym][handler_type] : 
      (handler_type == :event_handler ? 'update' : 'text')
  end

end

YAML.load_file("#{RAILS_ROOT}/config/virtual_agent.yml").each do |k, v|
  VAConfig.const_set(k.upcase, Helpdesk::prepare(v))
end
