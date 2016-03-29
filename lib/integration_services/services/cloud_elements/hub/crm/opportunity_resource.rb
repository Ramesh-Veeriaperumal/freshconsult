module IntegrationServices::Services
  module CloudElements::Hub::Crm
    class OpportunityResource < CloudElements::CloudElementsResource
       
      def get_fields(fields=[])
        request_url = "#{cloud_elements_api_url}/hubs/crm/objects/#{@service.meta_data[:object]}/metadata"
        response = http_get request_url do |req|
          req.headers = authorization_header
        end
        process_response(response, 200) do |fields|
          return fields
        end
      end

      def stage_name_picklist_values
        stage_field = get_fields(["StageName"])
        stage_field["picklistValues"].map do |picklistvalue|
          [ picklistvalue["label"], picklistvalue["value"] ]
        end
      end
       
    end
  end
end