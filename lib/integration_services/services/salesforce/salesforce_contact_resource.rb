module IntegrationServices::Services
  module Salesforce
    class SalesforceContactResource < SalesforceResource

      def find query_string
        soql_contact = "SELECT Id, Name, AccountId, Account.Name, Email, Phone, MobilePhone, freshdesk__Freshdesk_Twitter_UserName__c, 
        freshdesk__Freshdesk_Facebook_Id__c, freshdesk__Freshdesk_External_Id__c FROM Contact WHERE #{query_string}"
        request_url = "#{salesforce_rest_url}/query?q=#{soql_contact}"
        url  = URI.encode(request_url.strip)
        response = http_get url
        process_response(response, 200) do |contact|
          return contact
        end
      end

      def find_user query_string      
        soql_contact = "SELECT Id FROM User WHERE #{query_string}"
        request_url = "#{salesforce_rest_url}/query?q=#{soql_contact}"
        url  = URI.encode(request_url.strip)
        response = http_get url  
        process_response(response, 200) do |contact|
          return contact
        end
      end

      def create request_body
        request_url = "#{salesforce_rest_url}/sobjects/Contact"
        response = http_post request_url, request_body.to_json
        process_response(response, 201) do |contact|
          return contact
        end
      end 

      def get_fields
        request_url = "#{salesforce_old_rest_url}/sobjects/Contact/describe"
        response = http_get request_url
        process_response(response, 200, &format_fields_block)
      end

      def get_selected_fields fields, email
        return { "totalSize" => 0, "done" => true, "records" => [] } if email.blank?
        address_fields = ["MailingStreet","MailingCity","MailingState","MailingCountry","MailingPostalCode"]
        fields = format_selected_fields fields, address_fields
        email = escape_reserved_chars email
        soql = "SELECT #{fields} FROM Contact WHERE Email = '#{email}'"
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