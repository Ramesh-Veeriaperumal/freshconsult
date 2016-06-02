module IntegrationServices::Services
  module Freshsales
    class FreshsalesContactResource < FreshsalesResource

      RELATIONAL_FIELDS = { 
                            "lead_source_id" => ["source", "lead_source"], 
                            "owner_id" => ["owner", "users"], 
                            "campaign_id" => ["campaign", "campaigns"] 
                          }
      
      def get_fields
        request_url = "#{server_url}/settings/contacts/fields.json"
        response = http_get request_url
        opt_fields = { "display_name" => "Full name" }
        process_response(response, 200, &format_fields_block(opt_fields))
      end

      def get_selected_fields fields, value
        return { "contacts" => [], "type" => "contact" } if value[:email].blank?
        contact_response = filter_by_email value[:email]
        if contact_response["contacts"].blank?
          contact_response["type"] = "contact"
          return contact_response 
        end
        fields = fields.split(",")
        contact_id = contact_response["contacts"].first["id"]
        url = "#{server_url}/contacts/#{contact_id}.json"
        relational_fields = fields & RELATIONAL_FIELDS.keys
        request_url = if relational_fields.present?
          include_resources = relational_fields.map do |relational_field|
            RELATIONAL_FIELDS[relational_field].first
          end
          encode_path_with_params url, :include => include_resources.join(",")
        else
          url
        end
        response = http_get request_url
        process_response(response, 200) do |contact|
          return process_result(contact, fields, relational_fields, "contact")
        end
      end

      def filter_by_email email
        request_url = "#{server_url}/filtered_search/contact"
        filters = [ construct_filter("contact_email.email","is_in",email) ]
        request_body = filter_request_body filters
        response = http_post request_url, request_body.to_json
        process_response(response, 200) do |contact|
          return contact
        end
      end

      def resource_relational_fields
        RELATIONAL_FIELDS
      end
    end
  end
end 