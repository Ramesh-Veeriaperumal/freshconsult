module Integrations
  class IntegrationOperationsHandler


    def slack options
      operation_event = options[:operation_event]
      act_hash = options[:act_hash].symbolize_keys
      service_class = IntegrationServices::Service.get_service_class("slack_v2")
      installed_app = Account.current.installed_applications.with_name("slack_v2").first

      if operation_event.present? && installed_app.present? && service_class.present?
        if operation_event == "execute_rule" # Freshdesk To Slack
          triggered_event = options[:triggered_event]
          act_obj = options[:act_on_class].constantize.find(options[:act_on_id])
          payload = { :act_on_object => act_obj, :act_hash => act_hash, :triggered_event => triggered_event }
          service_obj = service_class.new(installed_app, payload)
          service_obj.receive("push_to_slack")
        elsif operation_event == "create_ticket" # Slack to Freshdesk
          payload = { :act_hash => act_hash }
          service_obj = service_class.new(installed_app, payload)
          service_obj.receive("slash_command")
        end
      end
    end

  end
end
