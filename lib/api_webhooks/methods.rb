module ApiWebhooks::Methods
  include ApiWebhooks::Constants
  include Va::Util

  def allow_api_webhook?
    (!zendesk_import? && !freshdesk_webhook? && import_id.blank?)
  end

  def subscribe_event_create
    event_changes = MAP_CREATE_ACTION[self.class.name]
    send_subscribe_events(event_changes) if rule_exists?(MAP_CREATE_ACTION[self.class.name])
  end

  def subscribe_event_update
    event_changes = @model_changes.inject({}) do |filtered, (change_key, change_value)|
      filter_subscribe_event filtered, change_key, change_value
    end

    if event_changes.present?
      event_changes.merge! MAP_UPDATE_ACTION[self.class.name]
      send_subscribe_events(event_changes) if rule_exists?(MAP_UPDATE_ACTION[self.class.name])
    end
  end

  def filter_subscribe_event(filtered, change_key, change_value)
    change_key = change_key.to_sym
    include_change_key(change_key) ? filtered.merge!(change_key => change_value) : filtered
  end

  def include_change_key(change_key)
    return true if MAP_SUBSCRIBE_EVENT[self.class.name].include?(change_key)

    @event_flexifields ||= Account.current.event_flexifields_with_ticket_fields_from_cache
    @event_flexifields.any? { |event_field| event_field.flexifield_name.to_sym == change_key }
  end

  def map_class class_name
    attr_map = {"Helpdesk::Ticket" => :tickets, "User" => :users, "Helpdesk::Note" => :notes}
    attr_map[class_name]
  end

  def send_subscribe_events(event_changes)
    evaluate_on_id = self.send FETCH_EVALUATE_ON_ID[self.class.name]
    Integrations::ApiWebhookRuleWorker.perform_async(
      {:evaluate_on_id => evaluate_on_id,
       :current_events => event_changes, 
       :association => map_class(self.class.name)}
    )
  end

  def rule_exists?(constant_rule)
    rule_flag = false
    account.api_webhooks_rules_from_cache.each do |va|
      va.filter_data[:events].each do |e|
        e = e.symbolize_keys
        return rule_flag = true if(constant_rule[e[:name].to_sym] == e[:value].to_sym)
      end
    end
    rule_flag
  end
end
