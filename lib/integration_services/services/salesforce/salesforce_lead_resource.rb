module IntegrationServices::Services
  module Salesforce
    class SalesforceLeadResource < SalesforceResource

      def get_fields
        request_url = "#{salesforce_old_rest_url}/sobjects/Lead/describe"
        response = http_get request_url
        process_response(response, 200, &format_fields_block)
      end

      def get_selected_fields fields, email
        return { "totalSize" => 0, "done" => true, "records" => [] } if email.blank?
        address_fields = ["Street","City","State","Country","PostalCode"]
        fields = format_selected_fields fields, address_fields
        email = escape_reserved_chars email
        soql = "SELECT #{fields} FROM Lead WHERE Email = '#{email}' AND IsConverted = false"
        request_url = "#{salesforce_old_rest_url}/query"
        url = encode_path_with_params request_url, :q => soql 
        response = http_get url
        process_response(response, 200) do |contact|
          return contact
        end
      end        
    end
  end
end