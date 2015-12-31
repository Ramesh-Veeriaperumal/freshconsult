module IntegrationServices::Services
  module Salesforce
    class SalesforceAccountResource < SalesforceResource     

      def create request_body
        request_url = "#{salesforce_rest_url}/sobjects/Account"
        response = http_post request_url, request_body.to_json
        process_response(response, 201) do |account|
          return account
        end
      end

      def find fd_comp_name
        fd_comp_name = escape_reserved_chars fd_comp_name
        soql_account = "SELECT Id FROM Account WHERE Name = '#{fd_comp_name}'"
        request_url = "#{salesforce_rest_url}/query"
        url = encode_path_with_params request_url, :q => soql_account 
        response = http_get url
        process_response(response, 200) do |account|
          return account
        end
      end

      def get_fields
        request_url = "#{salesforce_old_rest_url}/sobjects/Account/describe"
        response = http_get request_url
        process_response(response, 200, &format_fields_block)
      end

      def get_selected_fields fields, value
        return { "totalSize" => 0, "done" => true, "records" => [] } if value[:company].blank? and value[:email].blank?
        address_fields = ["BillingStreet","BillingCity","BillingState","BillingCountry","BillingPostalCode"]
        fields = format_selected_fields fields, address_fields
        soql = if value[:company].present?
          company_name = escape_reserved_chars value[:company]
          "SELECT #{fields} FROM Account WHERE Name = '#{company_name}'"
        elsif value[:email].present?
          value[:email] = escape_reserved_chars value[:email]
          "SELECT #{fields} FROM Account WHERE Id IN (SELECT AccountId FROM Contact WHERE Email = '#{value[:email]}')"
        end
        request_url = "#{salesforce_old_rest_url}/query"
        url = encode_path_with_params request_url, :q => soql 
        response = http_get url
        process_response(response, 200) do |account|
          return account
        end
      end
    end
  end
end