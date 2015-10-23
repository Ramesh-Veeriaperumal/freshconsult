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
  API_WEBHOOK_RULE = 13

  # TODO-RAIL3:: Get these I18N based constants out of Initializers
  CREATED_DURING_VALUES = [
    [ :business_hours, "Business Hours", "business_hours"],
    [ :non_business_hours, "Non-Business Hours", "non_business_hours"],
    [ :holidays, "Holidays", "holidays"]
  ]

  CREATED_DURING_NAMES_BY_KEY = Hash[*CREATED_DURING_VALUES.map { |i| [i[2], i[1]] }.flatten]

  def self.handler(field, account, evaluate_on_type = nil)
    fetch_handler field, account, :rule, evaluate_on_type
  end

  def self.event_handler(field, account)
    fetch_handler field, account, :event
  end

  def self.negatable_columns(account)
    custom_fields = account.ticket_fields.custom_fields.collect { |field| field.name }
    custom_fields + DEFAULT_NEGATABLE_COLUMS
  end

  private

    def self.fetch_handler(field, account, handler_type, evaluate_on_type = nil)
      Rails.logger.debug "The field is : #{field}, handler_type is :#{handler_type},"
      field_key = fetch_field_key field, account, handler_type, evaluate_on_type
      handler_key = FIELDS[handler_type][field_key] || "fallback"

      Rails.logger.debug "field_key is : #{field_key}  handler_key is : #{handler_key}"
      VA_HANDLERS[handler_type][handler_key.to_sym]
    end

    def self.fetch_field_key(field, account, handler_type, evaluate_on_type = nil)
      (FIELDS[handler_type].include? field) ? field : (custom_field_handler_type field.to_s, account, evaluate_on_type)
    end
  
    def self.custom_field_handler_type(field, account, evaluate_on_type = nil)
      case evaluate_on_type
      when "ticket"
        fetch_ticket_field field, account
      when "requester"
        contact_field = account.contact_form.custom_contact_fields.detect{ |cnf| cnf.name == field }
        contact_field.present? ? contact_field.field_type.to_sym : :default
      when "company"
        company_field = account.company_form.custom_company_fields.detect{ |csf| csf.name == field }
        company_field.present? ? company_field.field_type.to_sym : :default
      else
        fetch_ticket_field field, account
      end
    end

    def self.fetch_ticket_field field, account
      ff = account.flexifields_with_ticket_fields_from_cache.detect{ |ff| 
          ff.flexifield_name == field || ff.flexifield_alias == field }
      ticket_field = ff.present? ? ff.ticket_field : nil
      ticket_field.present? && ticket_field.parent_id.nil? ? ticket_field.field_type.to_sym : :default
    end
end

YAML.load_file("#{Rails.root}/config/virtual_agent.yml").each do |k, v|
  VAConfig.const_set(k.upcase, Helpdesk::prepare(v))
end
YAML.load_file("#{Rails.root}/config/va_handlers.yml").each do |k, v|
  VAConfig.const_set(k.upcase, Helpdesk::prepare(v))
end
