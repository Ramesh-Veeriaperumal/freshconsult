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
          call_service_object(installed_app, payload, "push_to_slack")
        elsif operation_event == "create_ticket" # Slack to Freshdesk
          payload = { :act_hash => act_hash }
          call_service_object(installed_app, payload, "slash_command")
        elsif operation_event == "create_ticket_v3"
          payload = { :act_hash => act_hash }
          act_hash[:channel_name] == "directmessage" ? call_service_object(installed_app, payload, "slash_command_v3") : call_service_object(installed_app, payload, "slash_command")
        end
      else
        raise StandardError, "IntegrationOperationsHandler else block raise error! Account id is #{Account.current.id} "
      end
    end

    def office365 options
      act_hash = options[:act_hash].symbolize_keys
      installed_app = Account.current.installed_applications.with_name("office365").first
      if installed_app.present?
        triggered_event = options[:triggered_event]
        act_obj = options[:act_on_class].constantize.find(options[:act_on_id])
        payload = { :act_on_object => act_obj, :act_hash => act_hash, :triggered_event => triggered_event }
        service_obj = ::IntegrationServices::Services::Office365Service.new(installed_app, payload)
        service_obj.receive('send_email')
      else
        raise StandardError, "IntegrationOperationsHandler else block raise error! Account id is #{Account.current.id} "
      end
    end

    def call_service_object(installed_app, payload, method)
      service_obj = ::IntegrationServices::Services::SlackService.new(installed_app, payload)
      service_obj.receive(method)
    end

  end
end
