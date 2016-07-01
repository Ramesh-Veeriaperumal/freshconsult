module InstalledAppBusinessRules::Methods
    
    include InstalledAppBusinessRules::Constants
    include Va::Util

    def allow_inst_app_business_rule?
      !zendesk_import? && !freshdesk_webhook? && !customer_import?
    end
    
    def inst_app_business_event_create
      event_changes = MAP_CREATE_ACTION[self.class.name]
      send_inst_app_biz_events(:create) if inst_app_biz_rule_exists?(MAP_CREATE_ACTION[self.class.name])
    end

    def inst_app_business_event_update
      event_changes = @model_changes.inject({}) do |filtered, (change_key, change_value)| 
                        inst_app_biz_filter_event filtered, change_key, change_value
                      end

      unless event_changes.blank?                                                                 
        event_changes.merge! MAP_UPDATE_ACTION[self.class.name] 
        send_inst_app_biz_events(:update) if inst_app_biz_rule_exists?(MAP_UPDATE_ACTION[self.class.name])
      end
    end

    def inst_app_biz_filter_event filtered, change_key, change_value
      change_key = change_key.to_sym
      (MAP_SUBSCRIBE_EVENT[self.class.name].include?(change_key)) ? filtered.merge!({change_key => change_value}) : filtered
    end

  def send_inst_app_biz_events(event)
    evaluate_on_id = self.send FETCH_EVALUATE_ON_ID[self.class.name]
    Integrations::InstalledAppBusinessRuleWorker.perform_async(
      {:evaluate_on_id => evaluate_on_id,
       :current_event => event, 
       :association => map_class(self.class.name)}
    )
  end

  def inst_app_biz_rule_exists?(constant_rule)
    rule_flag = false
    account.installed_app_business_rules_from_cache.each do |va|
      va.filter_data.each do |e|
        entity = e[:action_performed][:entity].downcase
        action = e[:action_performed][:action]
        e = e.symbolize_keys
        return rule_flag = true if(constant_rule["#{entity}_action".to_sym] == action)
      end
    end
    rule_flag
  end
end