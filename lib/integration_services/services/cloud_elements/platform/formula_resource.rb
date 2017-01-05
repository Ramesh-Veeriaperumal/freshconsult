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

      def update_instance
        request_url = "#{cloud_elements_api_url}/formulas/#{@service.meta_data[:formula_id]}/instances/#{@service.meta_data[:formula_instance_id]}"
        response = http_put( request_url, @service.payload )
        process_response(response, 200) do |element_instance|
          return element_instance
        end
      end

      def delete_instance
        request_url = "#{cloud_elements_api_url}/formulas/#{@service.meta_data[:formula_template_id]}/instances/#{@service.meta_data[:id]}"
        response = http_delete request_url
        process_response(response, 200, 404) do |resp|
          return resp
        end
      end

      def get_execution
        request_url = "#{cloud_elements_api_url}/formulas/instances/#{@service.meta_data[:instance_id]}/executions?pageSize=#{@service.meta_data[:page_size]}"
        response = http_get request_url
        process_response(response, 200) do |resp|
          return resp
        end
      end

      def get_failure_step_id
        request_url = "#{cloud_elements_api_url}/formulas/instances/executions/#{@service.meta_data[:execution_id]}/steps"
        response = http_get request_url
        body = JSON.parse response.body
        return nil if response.status != 200 && body.size > 0
        body.first["id"] # first step in the response is the last executed step -Error.
      end

      def get_failure_reason
        request_url = "#{cloud_elements_api_url}/formulas/instances/executions/steps/#{@service.meta_data[:step_execution_id]}/values"
        response = http_get request_url
        body = JSON.parse response.body
        return nil if response.status != 200 && body.size > 0
        reason = body.select{|b| b["key"].include? "response.body"}.first
        reason["value"]
      rescue => e
        nil
      end

    end
  end
end