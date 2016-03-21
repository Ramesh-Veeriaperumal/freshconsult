module IntegrationServices::Services
  module Salesforce
    class SalesforceOpportunityResource < SalesforceResource

      def create request_body
        request_url = "#{salesforce_rest_url}/sobjects/Opportunity"
        response = http_post request_url, request_body.to_json
        process_response(response, 201) do |opportunity|
          return opportunity
        end
      end

      def get_fields(fields=[])
        request_url = "#{salesforce_old_rest_url}/sobjects/Opportunity/describe"
        response = http_get request_url
        process_response(response, 200, &format_fields_block(fields))
      end

      def get_selected_fields fields, value
        return { "totalSize" => 0, "done" => true, "records" => [] } if value[:account_id].blank?
        fields = format_selected_fields fields
        link_status, linked_opportunity = integrated_remote_resource(value[:account_id],fields)
        return linked_opportunity if linked_opportunity.present? && linked_opportunity["records"].present?
        soql = "SELECT #{fields} FROM Opportunity WHERE AccountId = '#{value[:account_id]}' AND IsClosed = false ORDER BY CloseDate ASC NULLS LAST, CreatedDate ASC NULLS LAST LIMIT 5"
        request_url = "#{salesforce_old_rest_url}/query"
        url = encode_path_with_params request_url, :q => soql 
        response = http_get url
        process_response(response, 200) do |opportunity|
          opportunity["records"].each { |opportunity_record| opportunity_record["link_status"] = link_status } if @service.payload[:ticket_id].present?
          return opportunity
        end
      end

      def integrated_remote_resource(account_id,fields)
        link_status, linked_opportunity = nil, nil
        unless @service.payload[:ticket_id].blank?
          integrated_resource = @service.installed_app.integrated_resources.find_by_local_integratable_id(@service.payload[:ticket_id]) 
          link_status = false
          unless integrated_resource.blank?
            link_status = true
            linked_opportunity = find integrated_resource.remote_integratable_id, fields, account_id
            unless linked_opportunity["records"].blank?
              linked_opportunity["records"].first["link_status"] = link_status
              linked_opportunity["records"].first["unlink_status"] = link_status
            end
          end
        end
        [ link_status, linked_opportunity ]
      end

      def find(opportunity_id,fields,account_id)
        return { "totalSize" => 0, "done" => true, "records" => [] } if opportunity_id.blank? || account_id.blank?
        fields = fields.split(",")
        fields << "IsDeleted"
        fields.uniq!
        fields = fields.join(",")
        soql = "SELECT #{fields} FROM Opportunity WHERE Id = '#{opportunity_id}' AND AccountId = '#{account_id}'"
        request_url = "#{salesforce_rest_url}/queryAll"
        url = encode_path_with_params request_url, :q => soql 
        response = http_get url
        process_response(response, 200) do |opportunities|
          return opportunities
        end
      end

      def format_fields_block(fields=[])
        fields_block = lambda do |fields_hash|
          fields_hash = fields_hash["fields"]
          field_labels = Hash.new
          fields_hash.each do |field|
           field_label = CGI.escapeHTML(RailsFullSanitizer.sanitize(field["label"]))
           field_labels[field["name"]] = field_label if field_label.present?
           return field if fields.present? && field["name"] == fields[0]
          end
          field_labels
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