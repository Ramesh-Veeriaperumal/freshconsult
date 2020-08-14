module Helpdesk::IrisNotifications
  include KafkaCollector::CollectorRestClient
  include CentralPublish::CRECentralUtil

  ERROR_CODES = [500, 401, 404, 400].freeze
  IRIS_TIMEOUT = 10

  def push_data_to_service(_url, data)
    msg_id = generate_msg_id(data)
    post_to_collector(data.to_json, msg_id, true, IRIS_TIMEOUT)
  end

  def post_to_iris(url, data)
    host = [IrisNotificationsConfig['collector_host'], url].join('')
    options = {
      body: data.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'service' => IrisNotificationsConfig['service_token']
      },
      timeout: IRIS_TIMEOUT
    }
    response = HTTParty.post(host, options)
    raise "IRISAPIException: Response Code: #{response.code}" if response.nil? || ERROR_CODES.include?(response.code)
  rescue Exception => e
    Rails.logger.error "IRISAPIException #{e} data: #{data}"
    NewRelic::Agent.notice_error(e)
  end

  def fetch_data_from_service(url, data)
    host = [IrisNotificationsConfig['collector_host'], url].join('')
    options = {
      query: data,
      headers: {
        'Content-Type' => 'application/json',
        'service' => IrisNotificationsConfig['service_token']
      },
      timeout: IRIS_TIMEOUT
    }
    response = HTTParty.get(host, options)
    raise "IRISAPIException: Response Code: #{response.code}" if response.nil? || ERROR_CODES.include?(response.code)
    response.parsed_response
  rescue Exception => e
    Rails.logger.error "IRISAPIException #{e} data: #{data}"
    NewRelic::Agent.notice_error(e)
    return []
  end

  def announcements_collect_path(dashboard_id)
    "/announcements/#{dashboard_id}"
  end

  def announcement_viewers_path(dashboard_id, announcement_id)
    "/announcements/#{dashboard_id}/#{announcement_id}/read_by"
  end
end
