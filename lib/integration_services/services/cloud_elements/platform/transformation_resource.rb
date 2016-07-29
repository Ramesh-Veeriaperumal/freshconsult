module IntegrationServices::Services
  module CloudElements::Platform
    class TransformationResource < CloudElements::CloudElementsResource

      def create_instance_level_transformation
        request_url = "#{instance_level_transformation_url}"
        response = http_post( request_url, @service.payload )
        process_response(response, 200) do |transformation|
          return transformation
        end 
      end

      def update_instance_level_transformation
        request_url = "#{instance_level_transformation_url}"
        response = http_put( request_url, @service.payload )
        process_response(response, 200) do |transformation|
          return transformation
        end 
      end

      private

        def instance_level_transformation_url
          "#{cloud_elements_api_url}/instances/#{@service.meta_data[:instance_id]}/transformations/#{@service.meta_data[:object]}"
        end

    end
  end
end