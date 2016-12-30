module IntegrationServices::Services
  module CloudElements::Platform
    class ElementInstanceResource < CloudElements::CloudElementsResource
       
      def create_instance
        request_url = "#{cloud_elements_api_url}/instances"
        response = http_post( request_url, @service.payload )
        process_response(response, 200) do |element_instance|
          return element_instance
        end
      end

      def delete_instance
        request_url = "#{cloud_elements_api_url}/instances/#{@service.meta_data[:id]}"
        response = http_delete request_url
        process_response(response, 200, 404) do |resp|
          return resp
        end
      end

      def get_configuration
        request_url = "#{cloud_elements_api_url}/instances/#{@service.meta_data[:element_instance_id]}/configuration"
        response = http_get request_url
        process_response(response, 200) do |resp|
          return resp.select{|res| res["key"] == "event.poller.refresh_interval" || res["key"] == "event.notification.enabled"}
        end
      end

      def update_configuration
        request_url = "#{cloud_elements_api_url}/instances/#{@service.meta_data[:element_instance_id]}/configuration/#{@service.meta_data[:config_id]}"
        response = http_patch( request_url, @service.payload.to_json )
        process_response(response, 200) do |element_instance|
          return element_instance
        end

      end
    end
  end
end