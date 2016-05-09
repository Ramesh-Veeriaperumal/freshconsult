module IntegrationServices::Services
  module CloudElements::Hub::Crm
    class OpportunityResource < CloudElements::CloudElementsResource
       
      def get_fields(fields=[])
        request_url = "#{cloud_elements_api_url}/hubs/crm/objects/#{@service.meta_data[:object]}/metadata"
        response = http_get request_url do |req|
          req.headers = authorization_header
        end
        process_response(response, 200) do |fields|
          return fields
        end
      end

      def get_field_properties
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{@service.meta_data[:object]}/fields/#{@service.meta_data[:field]}"
        response = http_get request_url do |req|
          req.headers = authorization_header
        end
        process_response(response, 200) do |fields|
          return fields
        end
      end
       
    end
  end
end
