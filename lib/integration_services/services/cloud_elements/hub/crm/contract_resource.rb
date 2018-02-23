module IntegrationServices::Services
  module CloudElements::Hub::Crm
    class ContractResource < CloudElements::CloudElementsResource
       
      def faraday_builder(b)
        super
        b.headers['Authorization'] = Integrations::CLOUD_ELEMENTS_AUTH_HEADER + "," + "Element #{@service.meta_data[:element_token]}"
      end

      def get_fields
        request_url = "#{cloud_elements_api_url}/hubs/crm/objects/#{@service.meta_data[:object]}/metadata"
        response = http_get request_url
        return 404 if response.status == 404
        process_response(response, 200) do |fields|
          return fields
        end
      end
      
      def get_selected_fields fields, value, app_name
        return { FRONTEND_OBJECTS[:totalSize] => 0, FRONTEND_OBJECTS[:done] => true, FRONTEND_OBJECTS[:records] => [] } if value[:account_id].blank?
        query = build_query value, app_name
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{@service.meta_data[:object]}?where=#{query}"
        response = http_get request_url
        safe_send("#{@service.meta_data[:app_name]}_selected_fields", fields, response, [200], "Contract") do |contract|
          return contract
        end
      end

      def build_query value, app_name
        URI.encode(OBJECT_QUERIES[:contract_resource][app_name] % {:account_id => value[:account_id]})
      end  

    end
  end
end
