module VAConfig
  #  def self.prepare(params) 
  #    if params.is_a?(Hash)
  #      params.symbolize_keys!
  #      params.each { |k, v| params[k] = self.prepare(v) }
  #    end
  #    
  #    return params 
  #  end
  
  RULES = { dispatcher: 1, scenario_automation: 2, supervisor: 3, observer: 4,
            service_task_dispatcher: 5, service_task_observer: 6, app_business_rule: 11,
            installed_app_business_rule: 12,
            api_webhook_rule: 13 }.freeze

  BUSINESS_RULE = RULES[:dispatcher]
  SCENARIO_AUTOMATION = RULES[:scenario_automation]
  SUPERVISOR_RULE = RULES[:supervisor]
  OBSERVER_RULE = RULES[:observer]
  SERVICE_TASK_DISPATCHER_RULE = RULES[:service_task_dispatcher]
  SERVICE_TASK_OBSERVER_RULE = RULES[:service_task_observer]
  APP_BUSINESS_RULE = RULES[:app_business_rule]
  INSTALLED_APP_BUSINESS_RULE = RULES[:installed_app_business_rule]
  API_WEBHOOK_RULE = RULES[:api_webhook_rule]
  DISPATCHER_RULE_TYPES = [RULES[:dispatcher], RULES[:service_task_dispatcher]].freeze
  OBSERVER_RULE_TYPES = [RULES[:observer], RULES[:service_task_observer]].freeze

  RULES_BY_ID = RULES.invert
  # TODO-RAIL3:: Get these I18N based constants out of Initializers
  CREATED_DURING_VALUES = [
    [ :business_hours, "Business Hours", "business_hours"],
    [ :non_business_hours, "Non-Business Hours", "non_business_hours"],
    [ :holidays, "Holidays", "holidays"]
  ]

  CREATED_DURING_NAMES_BY_KEY = Hash[*CREATED_DURING_VALUES.map { |i| [i[2], i[1]] }.flatten]

  ASSOCIATION_MAPPING = {
    dispatcher:              :va_rules,
    observer:                :observer_rules,
    supervisor:              :supervisor_rules,
    service_task_dispatcher: :service_task_dispatcher_rules,
    service_task_observer:   :service_task_observer_rules
  }.freeze

  def self.handler(field, account, evaluate_on_type = nil)
    fetch_handler field, account, :rule, evaluate_on_type
  end

  def self.event_handler(field, account)
    fetch_handler field, account, :event
  end

  def self.negatable_columns(account)
    filter_negatable_fields = proc { |field|
      field if field.flexifield_def_entry.flexifield_name.starts_with?('ff') && (field.field_type != 'custom_paragraph' || Account.current.launched?(:supervisor_multi_line_field))
    }
    custom_fields = account.ticket_fields.custom_fields.select(&filter_negatable_fields).collect(&:name)
    custom_fields + DEFAULT_NEGATABLE_COLUMS
  end

  private

    def self.fetch_handler(field, account, handler_type, evaluate_on_type = nil)
      field_key = fetch_field_key field, account, handler_type, evaluate_on_type
      handler_key = FIELDS[handler_type][field_key] || "fallback"
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
      return :hours_since_waiting_on_custom_status if since_custom_status? field, account

      ff = account.flexifields_with_ticket_fields_from_cache.detect{ |ff| 
          ff.flexifield_name == field || ff.flexifield_alias == field }
      ticket_field = ff.present? ? ff.ticket_field : nil
      ticket_field.present? && ticket_field.parent_id.nil? ? ticket_field.field_type.to_sym : :default
    end

    def self.since_custom_status? (field, account)
      return false unless field.to_s.include? Admin::AutomationConstants::TIME_AND_STATUS_BASED_FILTER[0]

      status_id = field.split('_').last
      status_index = field.index(status_id)
      field[0, status_index] == Admin::AutomationConstants::TIME_AND_STATUS_BASED_FILTER[0] + '_'
    end
end

YAML.load_file("#{Rails.root}/config/virtual_agent.yml").each do |k, v|
  VAConfig.const_set(k.upcase, Helpdesk::prepare(v))
end
YAML.load_file("#{Rails.root}/config/va_handlers.yml").each do |k, v|
  VAConfig.const_set(k.upcase, Helpdesk::prepare(v))
end
