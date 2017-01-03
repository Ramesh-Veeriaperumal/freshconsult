module IntegrationServices::Services
  module CloudElements::Hub::Crm
    class OpportunityResource < CloudElements::CloudElementsResource
       
      def faraday_builder(b)
        super
        b.headers['Authorization'] = Integrations::CLOUD_ELEMENTS_AUTH_HEADER + "," + "Element #{@service.meta_data[:element_token]}"
      end
      
      def create payload
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{@service.meta_data[:object]}"
        response = http_post request_url, payload.to_json
        process_response(response, 200) do |opportunity|
          return opportunity
        end
      end

      def get_fields(fields=[])
        request_url = "#{cloud_elements_api_url}/hubs/crm/objects/#{@service.meta_data[:object]}/metadata"
        response = http_get request_url
        process_response(response, 200) do |fields|
          return fields
        end
      end

      def get_field_properties
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{@service.meta_data[:object]}/fields/#{@service.meta_data[:field]}"
        response = http_get request_url
        process_response(response, 200) do |fields|
          return fields
        end
      end

      def get_selected_fields fields, value
        return { FRONTEND_OBJECTS[:totalSize] => 0, FRONTEND_OBJECTS[:done] => true, FRONTEND_OBJECTS[:records] => [] } if value[:account_id].blank?
        link_status, linked_opportunity = integrated_remote_resource(value[:account_id],fields)
        return linked_opportunity if linked_opportunity.present? && linked_opportunity[FRONTEND_OBJECTS[:records]].present?
        query = URI.encode "AccountId='#{value[:account_id]}' AND IsClosed=false&pageSize=5&orderBy=CloseDate ASC, CreatedDate ASC"
        request_url = "#{cloud_elements_api_url}/hubs/crm/opportunities?where=#{query}"
        response = http_get request_url
        opportunity = send("#{@service.meta_data[:app_name]}_selected_fields", fields, response, [200], "Opportunity")
        opportunity[FRONTEND_OBJECTS[:records]].each { |opportunity_record| opportunity_record["link_status"] = link_status } if @service.payload[:ticket_id].present?
        opportunity
      end
      
      def integrated_remote_resource(account_id,fields)
        link_status, linked_opportunity = nil, nil
        unless @service.payload[:ticket_id].blank?
          integrated_resource = @service.installed_app.integrated_resources.find_by_local_integratable_id(@service.payload[:ticket_id]) 
          link_status = false
          unless integrated_resource.blank?
            link_status = true
            linked_opportunity = find integrated_resource.remote_integratable_id, fields, account_id
            unless linked_opportunity[FRONTEND_OBJECTS[:records]].blank?
              linked_opportunity[FRONTEND_OBJECTS[:records]].first["link_status"] = link_status
              linked_opportunity[FRONTEND_OBJECTS[:records]].first["unlink_status"] = link_status
            end
          end
        end
        [ link_status, linked_opportunity ]
      end

      def find opportunity_id, fields, account_id
        return { FRONTEND_OBJECTS[:totalSize] => 0, FRONTEND_OBJECTS[:done] => true, FRONTEND_OBJECTS[:records] => [] } if opportunity_id.blank? || account_id.blank?
        fields = fields.split(",")
        fields << "IsDeleted"
        fields.uniq!
        fields = fields.join(",")
        query = URI.encode "AccountId='#{account_id}' AND Id='#{opportunity_id}'"
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{@service.meta_data[:object]}?where=#{query}"
        response = http_get request_url
        process_selected_fields(fields, response, [200], "Id", "Opportunity") do |opportunity|
          return opportunity
        end
      end

    end
  end
end
