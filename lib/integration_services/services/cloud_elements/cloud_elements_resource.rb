module IntegrationServices::Services
  module CloudElements
    class CloudElementsResource < IntegrationServices::GenericResource
<<<<<<< Updated upstream
      
    end
  end
end
=======
      include Constant

      def faraday_builder(b)
        super
        b.headers['Authorization'] = IntegrationServices::Services::CloudElements::Constant::AUTH_HEADER
      end
      
      def cloud_elements_api_url
        "#{@service.server_url}/elements/api-v2"
      end

      def get_oauth_url(rest_url)
        request_url = "#{cloud_elements_api_url}/#{rest_url}?apiKey=#{API_KEY}&apiSecret=#{API_SECRET}&callbackUrl=#{CALLBACK_URL}"
        response = http_get request_url
        process_response(response, 200) do |response|
          return response
        end
      end

      def process_response(response, *success_codes, &block)
        if success_codes.include?(response.status)
          yield parse(response.body)
        elsif response.status.between?(400, 499)
          error = parse(response.body)
          raise RemoteError.new(error['message'], response.status.to_s)
        else
          raise RemoteError.new("Unhandled error: STATUS=#{response.status} BODY=#{response.body}", response.status.to_s)
        end
      end

    end
  end
end 
>>>>>>> Stashed changes
