module IntegrationServices::Services
  module Freshsales
    class FreshsalesLeadResource < FreshsalesResource

      RELATIONAL_FIELDS = {  
                            "lead_stage_id" => ["lead_stage", "lead_stages"],
                            "lead_reason_id" => ["lead_reason", "lead_reasons"], 
                            "lead_source_id" => ["source", "lead_source"], 
                            "owner_id" => ["owner", "users"], 
                            "campaign_id" => ["campaign", "campaigns"], 
                            "territory_id" => ["territory", "territories"] 
                          }

      ENTITIES = [ "company", "deal" ]

      FIELDS =  { 
                  "company" =>  [ 
                                  "name", "address", "city", "state", "zipcode", "country", "number_of_employees", 
                                  "annual_revenue", "website", "phone"
                                ],
                  "deal" => [ "name", "amount", "expected_close" ]
                }

      FIELDS_MAPPING =  { 
                          "company" => Hash[*FIELDS["company"].map { |i| ["company_#{i}",i] }.flatten],
                          "deal" => Hash[*FIELDS["deal"].map { |i| ["deal_#{i}",i] }.flatten]
                        }


      SELECTOR_FIELDS = { 
                          "company" => { "industry_type_id" => "industry_types", "business_type_id" => "business_types" },
                          "deal" => { "deal_product_id" => "deal_products" }
                        }

      SELECTOR_MAPPING =  { 
                            "company" => Hash[*(SELECTOR_FIELDS["company"].keys).map { |i| ["company_#{i}",i] }.flatten],
                            "deal" => Hash[*(SELECTOR_FIELDS["deal"].keys).map { |i| ["deal_#{i}",i] }.flatten]
                          }

      def get_fields
        request_url = "#{server_url}/settings/leads/fields.json"
        response = http_get request_url
        opt_fields = { "display_name" => "Full name" }
        process_response(response, 200, &format_fields_block(opt_fields))
      end

      def get_selected_fields fields, value
        return { "leads" => [], "type" => "lead" } if value[:email].blank?
        lead_response = filter_by_email value[:email]
        if lead_response["leads"].blank?
          lead_response["type"] = "lead"
          return lead_response 
        end
        fields = fields.split(",")
        lead_results = lead_response["leads"].first(5)
        lead_ids = lead_results.map { |lead_result| lead_result["id"] }
        url = "#{server_url}/leads/%{lead_id}.json"
        relational_fields = fields & RELATIONAL_FIELDS.keys
        request_url = if relational_fields.present?
          include_resources = relational_fields.map do |relational_field|
            RELATIONAL_FIELDS[relational_field].first
          end
          encode_path_with_params url, { :include => include_resources.join(",") }, false, false
        else
          url
        end
        process_request lead_ids, request_url, fields, relational_fields
      end

      def process_request lead_ids, request_url, fields, relational_fields
        responses = []
        lead_block = lambda { |lead| return lead }
        lead_ids.each do |lead_id| 
          response = http_get(request_url % { :lead_id => lead_id })
          lead = process_response(response, 200, &lead_block)
          responses.push(lead)
        end
        return process_result(responses, fields, relational_fields, "lead")
      end

      def format_fields_block(opt_fields={})
        fields_block = lambda do |fields_hash|
          fields_hash = fields_hash["fields"]
          field_labels = Hash.new
          fields_hash.each do |field|
           field_label = CGI.escapeHTML(RailsFullSanitizer.sanitize(field["label"]))
           key = if field["base_model"] == "LeadCompany"
            "company_#{field["name"]}"
           elsif field["base_model"] == "LeadDeal"
            "deal_#{field["name"]}"
           else
            field["name"]
           end
           field_labels[key] = field_label if field_label.present?
          end
          field_labels.merge!(opt_fields) if opt_fields.present?
          field_labels
        end
      end

      def filter_by_email email
        request_url = "#{server_url}/filtered_search/lead"
        filters = [ construct_filter("lead_email.email","is_in",email) ]
        request_body = filter_request_body filters
        response = http_post request_url, request_body.to_json
        process_response(response, 200) do |lead|
          return lead
        end
      end

      def resource_relational_fields
        RELATIONAL_FIELDS
      end

      def process_result resources, fields, relational_fields, resource_type
        result = Hash.new
        result[RESOURCE_MAPPER[resource_type]] = []
        resources.each do |resource|
          lead_resource = resource[resource_type]
          relational_fields.each do |relational_field|
            key = resource_relational_fields[relational_field][1]
            lead_resource[relational_field] = resource[key].first["name"] || resource[key].first["display_name"] if resource[key].present?
          end
          result[RESOURCE_MAPPER[resource_type]].push(lead_resource)
        end
        result["type"] = resource_type
        get_custom_fields resource_type, fields, result
        process_entities result, fields, relational_fields, resource_type
      end

      def get_custom_fields resource_type, fields, result
        result[RESOURCE_MAPPER[resource_type]].each do |resource|
          selected_custom_fields = resource["custom_field"].keys & fields unless resource["custom_field"].blank?
          if selected_custom_fields.present?
            selected_custom_fields.each do |selected_custom_field|
              resource[selected_custom_field] = resource["custom_field"][selected_custom_field]
            end
          end
        end
        result
      end

      def process_entities result, fields, relational_fields, resource_type
        ENTITIES.each do |lead_entity|
          get_lead_association_fields fields, lead_entity, result
        end
        result
      end

      def get_lead_association_fields fields, lead_entity, result
        lead_entity_selector_fields = SELECTOR_FIELDS[lead_entity]
        lead_entity_fields_mapping = FIELDS_MAPPING[lead_entity]
        lead_entity_selector_mapping = SELECTOR_MAPPING[lead_entity]
        result["leads"].each do |lead|
          lead_entity_record = lead[lead_entity]
          next if lead_entity_record.blank?
          entity_lead_fields = lead_entity_fields_mapping.keys & fields
          if entity_lead_fields.present?
            entity_lead_fields.each do |entity_lead_field|
              lead[entity_lead_field] = lead_entity_record[lead_entity_fields_mapping[entity_lead_field]]
            end
          end
          entity_selector_fields = lead_entity_selector_mapping.keys & fields
          if entity_selector_fields.present?
            entity_selector_fields.each do |entity_selector_field|
              lead[entity_selector_field] = fetch_selector_fields(lead_entity_record[lead_entity_selector_mapping[entity_selector_field]],lead_entity_selector_fields[lead_entity_selector_mapping[entity_selector_field]])
            end
          end
        end
        result
      end

      def fetch_selector_fields id, selector_field
        request_url = "#{server_url}/selector/#{selector_field}"
        response = http_get request_url
        process_response(response, 200) do |selector_field_response|
          selector_field_response[selector_field].each do |selector_field_choice|
            return selector_field_choice["name"] if selector_field_choice["id"] == id
          end
        end
        nil
      end
    end
  end
end