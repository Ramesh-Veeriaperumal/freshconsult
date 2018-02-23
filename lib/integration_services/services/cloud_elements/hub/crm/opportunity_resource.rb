module IntegrationServices::Services
  module CloudElements::Hub::Crm
    class OpportunityResource < CloudElements::CloudElementsResource
       
      def faraday_builder(b)
        super
        b.headers['Authorization'] = Integrations::CLOUD_ELEMENTS_AUTH_HEADER + "," + "Element #{@service.meta_data[:element_token]}"
      end
      
      def create payload, app_name
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{@service.meta_data[:object]}"
        response = http_post request_url, payload.to_json
        process_response(response, 200) do |opportunity|
          opportunity = process_ids(opportunity, app_name)
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

      def get_selected_fields fields, value, app_name
        return { FRONTEND_OBJECTS[:totalSize] => 0, FRONTEND_OBJECTS[:done] => true, FRONTEND_OBJECTS[:records] => [] } if value[:account_id].blank?
        link_status, linked_opportunity = integrated_remote_resource(value[:account_id],fields,app_name, value[:isNewUI])
        return linked_opportunity if linked_opportunity.present? && linked_opportunity[FRONTEND_OBJECTS[:records]].present?
        query = build_query(value, app_name)
        request_url = "#{cloud_elements_api_url}/hubs/crm/opportunities?where=#{query}"
        response = http_get request_url
        opportunity = safe_send("#{app_name}_selected_fields", fields, response, [200], "Opportunity")
        opportunity[FRONTEND_OBJECTS[:records]].each { |opportunity_record| opportunity_record["link_status"] = link_status } if @service.payload[:ticket_id].present?
        opportunity
      end

      def build_query(value, app_name)
        URI.encode(OBJECT_QUERIES[:opportunity_resource][app_name] % {:account_id => value[:account_id]})
      end
      
      def integrated_remote_resource(account_id,fields,app_name,is_new_ui)
        link_status, linked_opportunity = nil, nil
        unless @service.payload[:ticket_id].blank?
          ticket_id = is_new_ui ?  fetch_ticket_id_using_display_id(@service.payload[:ticket_id]) : @service.payload[:ticket_id]
          integrated_resource = @service.installed_app.integrated_resources.find_by_local_integratable_id(ticket_id)
          link_status = false
          unless integrated_resource.blank?
            link_status = true
            linked_opportunity = find integrated_resource.remote_integratable_id, fields, account_id, app_name
            unless linked_opportunity[FRONTEND_OBJECTS[:records]].blank?
              linked_opportunity[FRONTEND_OBJECTS[:records]].first["link_status"] = link_status
              linked_opportunity[FRONTEND_OBJECTS[:records]].first["unlink_status"] = link_status
            end
          end
        end
        [ link_status, linked_opportunity ]
      end

      def find opportunity_id, fields, account_id, app_name
        return { FRONTEND_OBJECTS[:totalSize] => 0, FRONTEND_OBJECTS[:done] => true, FRONTEND_OBJECTS[:records] => [] } if opportunity_id.blank? || account_id.blank?
        fields = fields.split(",")
        fields << "IsDeleted"
        fields.uniq!
        fields = fields.join(",")
        query = URI.encode(OBJECT_QUERIES[:opportunity_id_resource][app_name] % {:account_id => account_id, :opportunity_id => opportunity_id})
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{@service.meta_data[:object]}?where=#{query}"
        response = http_get request_url
        safe_send("#{@service.meta_data[:app_name]}_selected_fields", fields, response, [200], "Opportunity") do |opportunity|
          return opportunity
        end
      end

      def fetch_ticket_id_using_display_id display_id
        Account.current.tickets.find_by_display_id(display_id).id
      end

    end
  end
end
