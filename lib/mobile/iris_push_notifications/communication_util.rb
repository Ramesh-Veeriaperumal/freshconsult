module Mobile::IrisPushNotifications::CommunicationUtil

    ERROR_CODES = [500, 401, 404, 400]

    def push_data_to_service(url, data)
      host = [IrisNotificationsConfig["platform_host"], url].join('')
      puts host
      options = {
        :body => data.to_json,
        :headers => {
          "Content-Type" => "application/json",
          "service" => IrisNotificationsConfig["service_token"]
        },
        timeout: 10
      }
      response = HTTParty.post(host, options)
      raise "IRISAPIException" if response.nil? || ERROR_CODES.include?(response.code)
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        raise "IrisApiError"
    end
end
