module IntegrationServices::Services
  module Freshsales
    class FreshsalesCommonResource < FreshsalesResource
      REQUIRED_FORM_FIELDS = ['Contact', 'Lead'].freeze

      def fetch_form_fields
        url = "#{@service.instance_url}/settings/forms"
        response = http_get url
        process_response(response, 200) do |resource|
          return process_result(resource['forms'])
        end
      end

      def fetch_dropdown_choices(payload)
        url = "#{server_url}#{payload[:url]}"
        response = http_get url
        process_response(response, 200) do |results|
          return { results: results.values.first }
        end
      end

      def fetch_autocomplete_results(payload)
        url = "#{server_url}#{payload[:url]}"
        response = http_get url
        process_response(response, 200) do |results|
          return { results: results }
        end
      end

      def process_result(resource)
        result = {}
        resource.each do |res|
          if REQUIRED_FORM_FIELDS.include?(res['field_class'])
            result[res['field_class']] = filter_system_information res
          end
        end
        result
      end

      def filter_system_information(resource)
        basic_information = resource['fields'].select { |x| x['name'] == 'basic_information' }.first
        basic_information['fields'].reject! { |x| x['name'] == 'system_information' }
        resource
      end
    end
  end
end
