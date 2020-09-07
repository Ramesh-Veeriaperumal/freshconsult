# frozen_string_literal: true

module IntegrationServices::Services
  module Freshworkscrm
    class FreshworkscrmCommonResource < FreshworkscrmResource
      REQUIRED_FORM_FIELDS = ['Contact'].freeze

      def faraday_builder(b)
        super
        b.headers['User-Agent'] = 'Freshsales_Native_Mobile'
      end

      def fetch_autocomplete_results(payload)
        url = "#{@service.instance_url}#{payload[:url]}"
        response = http_get url
        process_response(response, 200) do |results|
          return process_autocomplete_results(results)
        end
      end

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

      private

        def remove_email_field(fields)
          fields.reject! { |x| x['name'] == 'email' }
          email_field = fields.find { |field| field['name'] == 'emails' }
          email_field['type'] = 'email' if email_field
        end

        def handle_nested_emails(basic_fields)
          section_fields = basic_fields.select { |x| x['type'] == 'section' }
          section_fields.each do |sf|
            fields = sf['fields']
            remove_email_field(fields)
          end
        end

        def filter_system_information(resource)
          basic_information = resource['fields'].select { |x| x['name'] == 'basic_information' }.first
          basic_fields = basic_information['fields']
          basic_fields.reject! { |x| x['name'] == 'system_information' }
          remove_email_field basic_fields
          handle_nested_emails basic_fields
          sales_account_field = basic_fields.find { |field| field['name'] == 'sales_accounts' }
          if sales_account_field
            sales_account_field['field_options']['creatable'] = false
            sales_account_field['field_options']['remove_item_label'] = I18n.t('ticket_templates.remove')
          end
          resource
        end

        def process_result(resource)
          result = {}
          resource.each do |res|
            result[res['field_class']] = filter_system_information(res) if REQUIRED_FORM_FIELDS.include?(res['field_class'])
          end
          result
        end

        def process_autocomplete_results(results)
          results = results.map do |result|
            result['_id'] = result['id'] if result['id'].present?
            result
          end
          { results: results }
        end
    end
  end
end
