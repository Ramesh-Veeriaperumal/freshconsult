# frozen_string_literal: true

module IntegrationServices::Services
  module Freshworkscrm
    class FreshworkscrmResource < IntegrationServices::GenericResource
      RESOURCE_MAPPER = { 'contact' => 'contacts', 'sales_account' => 'sales_accounts', 'deal' => 'deals' }.freeze
      def self.default_http_options
        super
        @@default_http_options[:ssl] = { verify: true, verify_depth: 5 }
        @@default_http_options
      end

      def faraday_builder(b)
        super
        b.headers['Authorization'] = "Token token=#{@service.configs['auth_token']}"
      end

      def format_fields_block(opt_fields = {})
        fields_block = lambda do |fields_hash|
          fields_hash = fields_hash['fields']
          field_labels = {}
          fields_hash.each do |field|
            field_label = CGI.escapeHTML(RailsFullSanitizer.sanitize(field['label']))
            field_labels[field['name']] = field_label if field_label.present?
          end
          field_labels.merge!(opt_fields) if opt_fields.present?
          field_labels
        end
      end

      def process_response(response, *success_codes, &_block)
        if success_codes.include?(response.status)
          yield parse(response.body)
        else
          raise RemoteError, "Error: #{response.body}", response.status.to_s
        end
      end

      def server_url
        "#{@service.instance_url}/api"
      end

      def construct_filter(attribute, operator, value)
        { 'attribute': attribute, 'operator': operator, 'value': value }
      end

      def process_result(resource, fields, relational_fields, resource_type)
        result = {}
        result[RESOURCE_MAPPER[resource_type]] = []
        result[RESOURCE_MAPPER[resource_type]].push(resource[resource_type])
        relational_fields.each do |relational_field|
          key = resource_relational_fields[relational_field][1]
          next unless resource[key]

          resource[key].each do |relational_option|
            result[RESOURCE_MAPPER[resource_type]].first[relational_field] = relational_option['name'] || relational_option['display_name'] if relational_option['id'] == result[RESOURCE_MAPPER[resource_type]].first[relational_field]
          end
        end
        result['type'] = resource_type
        get_custom_fields resource_type, fields, result
      end

      def get_custom_fields(resource_type, fields, result)
        resource_custom_fields = result[RESOURCE_MAPPER[resource_type]].first['custom_field']
        selected_custom_fields = resource_custom_fields.keys & fields if resource_custom_fields.present?
        if selected_custom_fields.present?
          selected_custom_fields.each do |selected_custom_field|
            result[RESOURCE_MAPPER[resource_type]].first[selected_custom_field] = resource_custom_fields[selected_custom_field]
          end
        end
        result
      end

      def filter_request_body(filters = [{}], include_resources = nil)
        return {} if filters.blank?

        request_body = {}
        request_body['filter_rule'] = filters
        request_body['include'] = include_resources if include_resources.present?
        request_body
      end
    end
  end
end
