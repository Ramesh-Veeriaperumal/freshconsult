module IntegrationServices::Services
  module CloudElements::Platform
    class ObjectResource < CloudElements::CloudElementsResource

      def create_instance_level_object_definition
        request_url = "#{instance_level_object_definiton_url}"
        response = http_post( request_url, @service.payload )
        process_response(response, 200) do |object|
          return object
        end
      end

      def update_instance_level_object_definition
        request_url = "#{instance_level_object_definiton_url}"
        response = http_put( request_url, @service.payload )
        process_response(response, 200) do |object|
          return object
        end
      end

      private

        def instance_level_object_definiton_url
          "#{cloud_elements_api_url}/instances/#{@service.meta_data[:instance_id]}/objects/#{@service.meta_data[:object]}/definitions" 
        end

    end
  end
end