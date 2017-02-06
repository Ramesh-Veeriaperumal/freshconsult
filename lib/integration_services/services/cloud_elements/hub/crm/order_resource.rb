module IntegrationServices::Services
  module CloudElements::Hub::Crm
    class OrderResource < CloudElements::CloudElementsResource
       
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

      def get_selected_fields fields, value
        return { FRONTEND_OBJECTS[:totalSize] => 0, FRONTEND_OBJECTS[:done] => true, FRONTEND_OBJECTS[:records] => [] } if value[:account_id].blank?
        query = URI.encode "AccountId='#{value[:account_id]}'&pageSize=5&orderBy=CreatedDate ASC"
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{@service.meta_data[:object]}?where=#{query}"
        response = http_get request_url
        send("#{@service.meta_data[:app_name]}_selected_fields", fields, response, [200], "Order") do |order|
          return order
        end
      end 
       
    end
  end
end