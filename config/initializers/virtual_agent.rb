
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
  APP_BUSINESS_RULE = 11
  INSTALLED_APP_BUSINESS_RULE = 12

  CREATED_DURING_VALUES = [
    [ :business_hours, I18n.t('ticket.created_during.business_hours'), "business_hours"],
    [ :non_business_hours, I18n.t('ticket.created_during.non_business_hours'), "non_business_hours"],
    [ :holidays, I18n.t('ticket.created_during.holidays'), "holidays"]
  ]

  CREATED_DURING_NAMES_BY_KEY = Hash[*CREATED_DURING_VALUES.map { |i| [i[2], i[1]] }.flatten]

  def self.handler(field, account)
    field_type = DEFAULT_FIELDS[field]
    
    if field_type.nil?
      field_type = check_for_custom_field field, account
    end
    
    RAILS_DEFAULT_LOGGER.debug " The field is : #{field} field_type is : #{field_type}"
    HANDLERS[field_type[:handler].to_sym]
  end
  
  def self.check_for_custom_field(field, account)
    t_field = account.ticket_fields.find_by_name field.to_s
    t_field ? Helpdesk::TicketField::FIELD_CLASS[t_field.field_type.to_sym][:va_handler] : 
      'text'
  end
end



YAML.load_file("#{RAILS_ROOT}/config/virtual_agent.yml").each do |k, v|
  VAConfig.const_set(k.upcase, Helpdesk::prepare(v))
end
