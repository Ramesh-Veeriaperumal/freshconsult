module IntegrationServices::Services
  module CloudElements::Hub::Crm
    class ContactResource < CloudElements::CloudElementsResource
       
      def faraday_builder(b)
        super
        b.headers['Authorization'] = Integrations::CLOUD_ELEMENTS_AUTH_HEADER + "," + "Element #{@service.meta_data[:element_token]}"
      end

      def create request_body # used only for Ticket Sync
        request_url = "#{cloud_elements_api_url}/hubs/crm/objects/Contact"
        response = http_post request_url, request_body.to_json
        process_response(response, 200) do |account|
          return account
        end
      end

      def find query #Used fo getting Contact in Ticket Sync.
        request_url = "#{cloud_elements_api_url}/hubs/crm/objects/Contact?where=#{query}"
        url  = URI.encode(request_url.strip)
        response = http_get url
        process_response(response, 200) do |contact|
          return contact
        end
      end

      def find_by_id contact_id
        request_url = "#{cloud_elements_api_url}/hubs/crm/objects/Contact/#{contact_id}"
        url  = URI.encode(request_url)
        response = http_get url
        return 404 if response.status == 404
        process_response(response, 200) do |contact|
          return contact
        end
      end

       def find_user query_string
        request_url = "#{cloud_elements_api_url}/hubs/crm/User?where=#{URI.encode(query_string)}"
        response = http_get request_url
        process_response(response, 200) do |contact|
          return contact
        end
      end

      def get_fields
        request_url = "#{cloud_elements_api_url}/hubs/crm/objects/#{@service.meta_data[:object]}/metadata"
        response = http_get request_url
        process_response(response, 200) do |fields|
          return fields
        end
      end
    
      def get_selected_fields fields, email
        # get the Contact from Salesforce for the Given Email.
        # {"attributes" => {"type" => "Contact"}, "Name" => "contactName", "Email"=> "contactName@gmail.com"}
        return { FRONTEND_OBJECTS[:totalSize] => 0, FRONTEND_OBJECTS[:done] => true, FRONTEND_OBJECTS[:records] => [] } if email.blank?
        query = "Email='#{email}'"
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{@service.meta_data[:object]}?where=#{query}"
        response = http_get request_url
        send("#{@service.meta_data[:app_name]}_selected_fields", fields, response, [200], "Contact") do |contact|
          return contact
        end
      end  

    end
  end
end