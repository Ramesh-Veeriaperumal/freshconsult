module IntegrationServices::Services
  module CloudElements
    class CloudElementsResource < IntegrationServices::GenericResource
      include Integrations::CloudElements::Crm::Constant
      include Integrations::CloudElements::Crm::CrmResourceUtil

      def faraday_builder(b)
        super
        b.headers['Authorization'] = Integrations::CLOUD_ELEMENTS_AUTH_HEADER
      end
      
      def cloud_elements_api_url
        "#{@service.server_url}/elements/api-v2"
      end

      def self.default_http_options
        @@default_http_options ||= {
          :request => {:timeout => 60, :open_timeout => 60},
          :ssl => {:verify => false, :verify_depth => 30},
          :headers => {}
        }
      end

      def process_response(response, *success_codes, &block)
        if success_codes.include?(response.status)
          yield parse(response.body)
        elsif response.status.between?(400, 499)
          error = parse(response.body)
          raise RemoteError.new(error['message'], response.status.to_s)
        else
          raise RemoteError.new("Unhandled error: STATUS=#{response.status} BODY=#{response.body}", response.status.to_s)
        end
      end

      def process_selected_fields(fields, response, success_codes, object_id, type)
        if success_codes.include? response.status
          response_hash = Hash.new
          fields_array = fields.split(",")
          fields_array.push(object_id)
          field_response = parse(response.body)
          response_hash = { FRONTEND_OBJECTS[:totalSize] => 0, FRONTEND_OBJECTS[:done] => true, FRONTEND_OBJECTS[:records] => [] }
          field_response.each do |response|
            hash = { FRONTEND_OBJECTS[:attributes]=> {FRONTEND_OBJECTS[:type] => type}}
            fields_array.each do |field|
              hash[field] = response[field]
            end
            response_hash[FRONTEND_OBJECTS[:records]].push(hash)
          end
        end
        response_hash
      end

    end
  end
end 
