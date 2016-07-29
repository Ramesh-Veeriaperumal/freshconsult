module IntegrationServices::Services
  module CloudElements::Hub::Crm
    class AccountResource < CloudElements::CloudElementsResource
       
      def faraday_builder(b)
        super
        b.headers['Authorization'] = Integrations::CLOUD_ELEMENTS_AUTH_HEADER + "," + "Element #{@service.meta_data[:element_token]}"
      end

      def get_fields
        request_url = "#{cloud_elements_api_url}/hubs/crm/objects/#{@service.meta_data[:object]}/metadata"
        response = http_get request_url
        process_response(response, 200) do |fields|
          return fields
        end
      end
       
    end
  end
end