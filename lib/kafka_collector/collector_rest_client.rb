module KafkaCollector
  module CollectorRestClient
    POST_TO_COLLECTOR_TIMEOUT = 2
    def post_to_collector(data, msg_id=nil, is_channel_token=true, timeout = POST_TO_COLLECTOR_TIMEOUT)
      token = is_channel_token ? KafkaCollectorConfig['service'] : CentralConfig['service_token']

      con = Faraday.new(KafkaCollectorConfig['kafka_collector_endpoint']) do |faraday|
        # Retry for 3 times with interval of 1 sec with backoff factor as 2
        # By default, timeout exceptions are retried
        faraday.request(:retry, max: 3, interval: 1, backoff_factor: 2)
        faraday.response :json, content_type: /\bjson$/ # log requests to STDOUT
        faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
      end
      response = con.post do |req|
        req.url KafkaCollectorConfig['path']
        req.headers['Content-Type'] = 'application/json'
        req.headers['service'] = token
        req.headers['x-request-id'] = msg_id if msg_id
        req.body = data
        req.options.timeout = timeout
      end
      response.status
    rescue StandardError => e
      Rails.logger.info "Error in connecting to collector. #{Account.current.id} #{data}, #{e.message}, #{e.backtrace}"
      raise e if JSON.parse(data)['payload_type'] == ChannelIntegrations::Constants::PAYLOAD_TYPES[:reply_from_helpkit]

      400
    end
  end
end
