module Integrations
  class RuleActionHandler

    def slack_trigger act_on, act_hash
      if act_hash.present?
        va_rule = act_hash.delete(:va_rule)
        options = {
          :act_hash => act_hash,
          :act_on_id => act_on.id,
          :act_on_class => act_on.class.name,
          :triggered_event => va_rule.triggered_event,
          :operation_event => "execute_rule",
          :operation_name => "slack",
        }
        Integrations::IntegrationsWorker.perform_async(options)
      end
    end
  end
end