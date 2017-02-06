module IntegrationServices::Services
  module CloudElements::Hub::Crm
    class FreshdeskTicketObjectResource < CloudElements::CloudElementsResource
      FD_TICKET_OBJECT = "freshdesk__Freshdesk_Ticket_Object__c"

      def faraday_builder(b)
        super
        b.headers['Authorization'] = Integrations::CLOUD_ELEMENTS_AUTH_HEADER + "," + "Element #{@service.meta_data[:element_token]}"
      end

      def find ticket_id
        query = URI.encode "freshdesk__TicketID__c=#{ticket_id}"
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{FD_TICKET_OBJECT}?where=#{query}"
        response = http_get request_url
        Rails.logger.debug "freshdesk__Freshdesk_Ticket_Object__c response: #{JSON.parse response.body}"
        process_response(response, 200) do |ticket|
          return ticket
        end
      end

      def check_fields_synced?
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{FD_TICKET_OBJECT}?pageSize=1"
        url  = URI.encode(request_url.strip)
        response = http_get url
        response.status == 200
      end

      def create request_body
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{FD_TICKET_OBJECT}"
        response = http_post request_url, request_body.to_json
        process_response(response, 200) do |ticket|
          return ticket
        end
      end

      def update request_body, object_id
        request_url = "#{cloud_elements_api_url}/hubs/crm/#{FD_TICKET_OBJECT}/#{object_id}"
        response = http_patch request_url, request_body.to_json
        process_response(response, 200) do |ticket|
          return ticket
        end
      end

    end
  end
end
