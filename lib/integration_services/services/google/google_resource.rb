module IntegrationServices::Services
  module Google
    class GoogleResource < IntegrationServices::GenericResource

      def faraday_builder(b)
        super
      end

      def process_response(response, *success_codes, &block)
        @logger.debug("Google Resource Logger : STATUS=#{response.status} BODY=#{response.body} ")
        if success_codes.include?(response.status) && response.body.present?
            temp_response = parse(response.body)
            yield temp_response
        elsif response.status.between?(400, 499)
          error = parse(response.body)
          raise RemoteError, "Error message: #{error.first['message']}", response.status.to_s
        end
        raise RemoteError, "Unhandled error: STATUS=#{response.status} BODY=#{response.body}"
      end

      def server_url
        "https://www.googleapis.com"
      end

      def api_key
        Integrations::API_KEYS["google_business_calendar"]
      end

    end
  end
end
