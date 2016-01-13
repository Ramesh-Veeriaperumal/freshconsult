module IntegrationServices::Services
  module CloudElements
    class ElementResource < CloudElementsResource
       
      def create_instance
        request_url = "#{cloud_elements_api_url}/instances"
        response = http_post( request_url, @service.payload )
        process_response(response, 200) do |element_instance|
          return element_instance
        end
      end
        
    end
  end
end