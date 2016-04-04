module Integrations
  class IntegrationRulesHandler

    def execute(act_on, configs)
      rule = configs.delete(:va_rule)

      if act_on.is_a?(Helpdesk::Ticket)
        return unless act_on.linked_to_integration?(rule.installed_application)
      elsif act_on.notable.is_a?(Helpdesk::Ticket)
        return unless act_on.notable.linked_to_integration?(rule.installed_application)
      end

      service_class = IntegrationServices::Service.get_service_class(configs.delete(:service))

      if service_class.present?
        event = configs.delete(:event)
        service_obj = service_class.new rule.installed_application, { :act_on_object => act_on }, configs
        service_obj.receive(event)
      end
    end

  end
end
