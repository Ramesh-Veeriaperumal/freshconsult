module Helpdesk::IrisNotifications
  ERROR_CODES = [500, 401, 404, 400].freeze

  def push_data_to_service(url, data)
    host = [IrisNotificationsConfig['collector_host'], url].join('')
    options = {
      body: data.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'service' => IrisNotificationsConfig['service_token']
      },
      timeout: 10
    }
    response = HTTParty.post(host, options)
    raise "IRISAPIException: Response Code: #{response.code}" if response.nil? || ERROR_CODES.include?(response.code)
  rescue Exception => e
    Rails.logger.error "IRISAPIException #{e} data: #{data}"
    NewRelic::Agent.notice_error(e)
  end
end
