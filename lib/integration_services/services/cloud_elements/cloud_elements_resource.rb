module IntegrationServices::Services
  module CloudElements
    class CloudElementsResource < IntegrationServices::GenericResource
      include Integrations::CloudElements::Crm::Constant

      def faraday_builder(b)
        super
        b.headers['Authorization'] = Integrations::CLOUD_ELEMENTS_AUTH_HEADER
      end
      
      def cloud_elements_api_url
        "#{@service.server_url}/elements/api-v2"
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
