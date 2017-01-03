module IntegrationServices::Services
  module CloudElements::Hub::Crm
    class LeadResource < CloudElements::CloudElementsResource
       
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
       
      def get_selected_fields fields, email
        return { FRONTEND_OBJECTS[:totalSize] => 0, FRONTEND_OBJECTS[:done] => true, FRONTEND_OBJECTS[:records] => [] } if email.blank?
        query = "Email='#{email}' AND IsConverted=false"
        query = URI.encode(query)
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{@service.meta_data[:object]}?where=#{query}"
        response = http_get request_url
        send("#{@service.meta_data[:app_name]}_selected_fields", fields, response, [200], "Lead") do |lead|
          return lead
        end
      end    

    end
  end
end
