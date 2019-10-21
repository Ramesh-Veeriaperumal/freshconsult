module KafkaCollector
  module CollectorRestClient
    POST_TO_COLLECTOR_TIMEOUT = 2
    def post_to_collector(data, msg_id=nil, is_channel_token=true)
      token = is_channel_token ? KafkaCollectorConfig['service'] : CentralConfig['service_token']

      con = Faraday.new(KafkaCollectorConfig['kafka_collector_endpoint']) do |faraday|
        faraday.response :json, content_type: /\bjson$/ # log requests to STDOUT
        faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
      end
      response = con.post do |req|
        req.url KafkaCollectorConfig['path']
        req.headers['Content-Type'] = 'application/json'
        req.headers['service'] = token
        req.headers['x-request-id'] = msg_id if msg_id
        req.body = data
        req.options.timeout = POST_TO_COLLECTOR_TIMEOUT
      end
      response.status
    rescue Exception => e
      Rails.logger.info "Error in connecting to collector. #{Account.current.id} #{data}, #{e.message}, #{e.backtrace}"
      400
    end
  end
end
