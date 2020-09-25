module Mobile::IrisPushNotifications::FreshfoneEvents::IncomingCall
  include Helpdesk::IrisNotifications
  include Mobile::Constants

  def notify_incoming_call_event_to_iris (message)
    logger.info "notify_incoming_call_event_to_iris  => #{message.to_json}"
    data = payload_data_to_iris message
    push_data_to_service(IrisNotificationsConfig["api"]["collector_path"], data)
  end

  private

  def caller_name
    return current_call.customer.name if current_call.customer.present?
    current_call.caller_number
  end

  def caller_info
    caller = {
      :name => caller_name,
      :number => current_call.caller_number
    }
  end

  def payload_data (message)
    payload = {
      :caller => caller_info,
      :call_id => message[:call_id],
      :ringing_duration => message[:ringing_duration],
      :call_sid => message[:call_sid],
      :number_id => message[:number_id],
      :notification_type => IRIS_FRESHFONE_NOTIFCATION_TYPES[:INCOMING_CALL],
      :freshfone_notification_type => message[:notification_type],
      :to_agents => message[:agents]
    }
  end

  def payload_data_to_iris (message)
    data = {
      :payload => payload_data(message),
      :payload_type => IRIS_FRESHFONE_NOTIFCATION_TYPES[:INCOMING_CALL],
      :account_id => message[:account_id].to_s
    }
  end
end
