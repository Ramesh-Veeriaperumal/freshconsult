module KafkaCollector
  module CollectorRestClient
    def post_to_collector(data, msg_id=nil)
      con = Faraday.new(KafkaCollectorConfig['kafka_collector_endpoint']) do |faraday|
        faraday.response :json, content_type: /\bjson$/ # log requests to STDOUT
        faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
      end
      response = con.post do |req|
        req.url KafkaCollectorConfig['path']
        req.headers['Content-Type'] = 'application/json'
        req.headers['service'] = KafkaCollectorConfig['service']
        req.headers['x-request-id'] = msg_id if msg_id
        req.body = data
      end
      Rails.logger.info "Response from kafka collector: #{Account.current.id} #{data} #{response.body}"
      response.status
    rescue Exception => e
      Rails.logger.info "Error in connecting to collector. #{Account.current.id} #{data}, #{e.message}, #{e.backtrace}"
      400
    end
  end
end
