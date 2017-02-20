module IntegrationServices::Services
  module CloudElements::Hub::Crm
    class AccountResource < CloudElements::CloudElementsResource
       
      def faraday_builder(b)
        super
        b.headers['Authorization'] = Integrations::CLOUD_ELEMENTS_AUTH_HEADER + "," + "Element #{@service.meta_data[:element_token]}"
      end

      def create request_body #used only for Salesforce Ticket Sync.
        request_url = "#{cloud_elements_api_url}/hubs/crm/objects/Account"
        response = http_post request_url, request_body.to_json
        process_response(response, 200) do |account|
          return account
        end
      end

      def find query #used only for Salesforce Ticket Sync.
        # finds Using AccountId as well as a query_string based on the query
        request_url = "#{cloud_elements_api_url}/hubs/crm/objects/Account/#{query}"
        response = http_get request_url
        process_response(response, 200) do |fields|
          return fields
        end
      end

      def get_fields
        request_url = "#{cloud_elements_api_url}/hubs/crm/objects/#{@service.meta_data[:object]}/metadata"
        response = http_get request_url
        process_response(response, 200) do |fields|
          return fields
        end
      end

      def get_account_name query
        request_url = URI.encode "#{cloud_elements_api_url}/hubs/crm/objects/#{@service.meta_data[:account_object]}?where=#{query}"
        response = http_get request_url
        account_response = JSON.parse response.body
        return nil if response.status != 200 || account_response.nil?
        account_response
      end

      def get_selected_fields fields, value, app_name
        return { FRONTEND_OBJECTS[:totalSize] => 0, FRONTEND_OBJECTS[:done] => true, FRONTEND_OBJECTS[:records] => [] } if value[:company].blank? && (value[:email].present? && value[:query].blank?)
        query = build_query(value, app_name)
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{@service.meta_data[:object]}?where=#{query}"
        response = http_get request_url
        send("#{@service.meta_data[:app_name]}_selected_fields", fields, response, [200], "Account") do |account|
          return account
        end
      end

      def build_query value, app_name
        if value[:email].present?
          URI.encode "#{value[:query]}"
        else
          URI.encode OBJECT_QUERIES[:account_resource][app_name] % {:company => value[:company]}
        end
      end
       
    end
  end
end