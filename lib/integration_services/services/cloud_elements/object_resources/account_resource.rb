module IntegrationServices::Services
  module CloudElements::ObjectResources
    class AccountResource < CloudElements::CloudElementsResource

      def get_fields(object)
        request_url = "#{cloud_elements_api_url}/objects/#{object}/metadata"
        response = http_get request_url
        process_response(response, 200) do |fields|
          return fields
        end
      end
    end
  end
end