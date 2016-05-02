module Integrations
  class IntegrationOperationsHandler


    def slack options
      operation_event = options[:operation_event]
      act_hash = options[:act_hash].symbolize_keys
      installed_app = Account.current.installed_applications.with_name("slack_v2").first

      if operation_event.present? && installed_app.present?
        if operation_event == "execute_rule" # Freshdesk To Slack
          triggered_event = options[:triggered_event]
          act_obj = options[:act_on_class].constantize.find(options[:act_on_id])
          payload = { :act_on_object => act_obj, :act_hash => act_hash, :triggered_event => triggered_event }
          service_obj = ::IntegrationServices::Services::SlackService.new(installed_app, payload)
          service_obj.receive("push_to_slack")
        elsif operation_event == "create_ticket" # Slack to Freshdesk
          payload = { :act_hash => act_hash }
          service_obj = ::IntegrationServices::Services::SlackService.new(installed_app, payload)
          service_obj.receive("slash_command")
        end
      else
        raise StandardError, "IntegrationOperationsHandler else block raise error! Account id is #{Account.current.id} "
      end
    end

  end
end
