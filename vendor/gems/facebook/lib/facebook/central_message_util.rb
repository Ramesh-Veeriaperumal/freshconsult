module Facebook::CentralMessageUtil
  CENTRAL_PAYLOAD_TYPES = {
    feeds: 'facebook_realtime_feeds'.freeze,
    message: 'facebook_realtime_messages'.freeze
  }.freeze

  def get_message(message, type)
    central_payload = JSON.parse(message)
    data = central_payload['data']

    message_is_from_central?(data, type) ? get_central_message(data, type) : message
  end

  def message_is_from_central?(data, type)
    data.present? && data['payload_type'] == type
  end

  def get_central_message(data, type)
    log_message(data, type)
    data['pod'] === ChannelFrameworkConfig['pod'] ? data['payload'].to_json : nil
  end

  def log_message(data, type)
    Rails.logger.debug "Facebook realtime #{type}, Account: #{data['account_id']}, msg_id: #{data['msg_id']}"
  end
end
