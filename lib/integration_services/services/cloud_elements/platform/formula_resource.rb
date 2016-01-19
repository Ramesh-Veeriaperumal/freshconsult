module IntegrationServices::Services
  module CloudElements::Platform
    class FormulaResource < CloudElements::CloudElementsResource

      def create_instance
        request_url = "#{cloud_elements_api_url}/formulas/#{@service.meta_data[:formula_id]}/instances"
        response = http_post( request_url, @service.payload )
        process_response(response, 200) do |element_instance|
          return element_instance
        end
      end

      def delete_instance
        request_url = "#{cloud_elements_api_url}/formulas/#{@service.meta_data[:formula_id]}/instances/#{@service.metadata[:formula_instance_id]}"
        response = http_delete request_url   
        process_response(response, 200) do |resp|
          return resp
        end
      end

    end
  end
end