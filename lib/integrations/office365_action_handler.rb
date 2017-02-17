module Integrations
  class Office365ActionHandler

    def office365_trigger act_on, act_hash
      if act_hash.present?
        va_rule = act_hash.delete(:va_rule)
        options = {
          :act_hash => act_hash,
          :act_on_id => act_on.id,
          :act_on_class => act_on.class.name,
          :triggered_event => va_rule.triggered_event,
          :operation_name => "office365",
        }
        act_on.va_rules_after_save_actions << {klass: "Integrations::IntegrationsWorker", method: :perform_async, args: options}
      end
    end
  end
end
