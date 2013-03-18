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

  def self.handler(field, account)
    fetch_handler field, account, :rule
  end

  def self.event_handler(field, account)
    fetch_handler field, account, :event
  end

  private

    def self.fetch_handler(field, account, type)
      field_key = fetch_field_key field, account, type
      handler_key = FIELDS[type][field_key]

      RAILS_DEFAULT_LOGGER.debug "The field is : #{field}, type is :#{type}, field_key is : #{field_key}  handler_key is : #{handler_key}"
      HANDLERS[type][handler_key.to_sym]
    end

    def self.fetch_field_key field, account, type
      (FIELDS[type].include? field) ? field : (custom_field_type field.to_s, account, type)
    end
  
    def self.custom_field_type field, account, type
      t_field = fetch_ticket_field field.to_s, account
      t_field.present? ? t_field.field_type.to_sym : :default
    end

    def self.fetch_ticket_field field, account
      (account.flexifield_def_entries.find_by_flexifield_name_or_flexifield_alias field).
                                                                          first.ticket_field
    end

end

YAML.load_file("#{RAILS_ROOT}/config/virtual_agent.yml").each do |k, v|
  VAConfig.const_set(k.upcase, Helpdesk::prepare(v))
end
YAML.load_file("#{RAILS_ROOT}/config/va_handler.yml").each do |k, v|
  VAConfig.const_set(k.upcase, Helpdesk::prepare(v))
end
