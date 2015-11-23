module IntegrationServices::Services
  module Salesforce
    class SalesforceCustomObjectResource < SalesforceResource
      FD_TICKET = "freshdesk__Freshdesk_Ticket_Object__c"
      def find ticket_id
        soql_contact = "SELECT Id FROM #{FD_TICKET} WHERE freshdesk__TicketID__c = #{ticket_id}.0"
        request_url = "#{salesforce_rest_url}/query?q=#{soql_contact}"
        url  = URI.encode(request_url.strip)
        response = http_get url
        process_response(response, 200) do |c_object|
          return c_object
        end
      end

      def create request_body
        request_url = "#{salesforce_rest_url}/sobjects/#{FD_TICKET}"
        response = http_post request_url, request_body.to_json
        process_response(response, 201) do |ticket|
          return ticket
        end
      end

      def update request_body, object_id
        request_url = "#{salesforce_rest_url}/sobjects/#{FD_TICKET}/#{object_id}"
        response = http_patch request_url, request_body.to_json
        process_response(response, 204) do |ticket|
          return ticket
        end
      end

      def check_fields_synced?(fields, object=nil)
       object ||= FD_TICKET
       soql_fields = "SELECT #{fields} FROM #{object} limit 1"
       request_url = "#{salesforce_rest_url}/query?q=#{soql_fields}"
       url  = URI.encode(request_url.strip)
       response = http_get url
       response.status == 200
      end      

      private

      def process_response(response, *success_codes, &block)
        body = parse(response.body)
        if success_codes.include?(response.status)
          if response.env[:new_token]
            @service.update_configs([{:key => 'oauth_token', :value => response.env[:new_token]}])
            http_reset
          end
          yield body
        elsif response.status == 400 && body[0]["message"].include?("Object type '#{FD_TICKET}' is not supported.")
          @service.deactivate_ticket_sync!
        elsif response.status.between?(400, 499)
          raise RemoteError, "Error message: #{body[0]['message']}", response.status.to_s
        else
          raise RemoteError, "Unhandled error: STATUS=#{response.status} BODY=#{response.body}"
        end
      end

    end
  end
end  