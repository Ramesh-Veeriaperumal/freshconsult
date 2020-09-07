# frozen_string_literal: false

module IntegrationServices::Services
  module Freshworkscrm
    class FreshworkscrmContactResource < FreshworkscrmResource
      RELATIONAL_FIELDS = { 'owner_id' => ['owner', 'users'], 'campaign_id' => ['campaign', 'campaigns'],
                            'sales_account_id' => ['sales_account', 'sales_accounts'],
                            'contact_status_id' => ['contact_status', 'contact_status'],
                            'creater_id' => ['creater', 'users'], 'updater_id' => ['updater', 'users'] }.freeze

      def create(payload, web_meta)
        request_url = "#{server_url}/contacts"
        request_body = { contact: payload[:entity] }
        response = http_post request_url, request_body.to_json
        process_create_response(response, web_meta, 200, 201) do |contact|
          return contact
        end
      end

      def get_selected_fields(fields, value)
        return { 'contacts' => [], 'type' => 'contact' } if value[:email].blank?

        contact_response = filter_by_email value[:email]
        if contact_response['contacts'].blank?
          contact_response['type'] = 'contact'
          return contact_response
        end
        fields = fields.split(',')
        contact_id = contact_response['contacts'].first['id']
        url = "#{server_url}/contacts/#{contact_id}.json"
        relational_fields = fields & RELATIONAL_FIELDS.keys
        include_resources = relational_fields.map { |relational_field| RELATIONAL_FIELDS[relational_field].first } if relational_fields.present?
        request_url = include_resources.present? ? encode_path_with_params(url, include: include_resources.join(',')) : url
        response = http_get request_url
        process_response(response, 200) { |contact| return process_result(contact, fields, relational_fields, 'contact') }
      end

      def fetch_fields
        request_url = "#{server_url}/settings/contacts/fields.json"
        response = http_get request_url
        opt_fields = { 'display_name' => 'Full name' }
        process_response(response, 200, &format_fields_block(opt_fields))
      end

      private

        def process_create_response(response, _web_meta, *success_codes, &_block)
          if success_codes.include?(response.status)
            yield parse(response.body)
          else
            raise RemoteError, "Error: #{response.body}", response.status.to_s
          end
        end

        def filter_by_email(email)
          request_url = "#{server_url}/filtered_search/contact"
          filters = [construct_filter('contact_email.email', 'is_in', email)]
          request_body = filter_request_body filters
          response = http_post request_url, request_body.to_json
          process_response(response, 200) do |contact|
            return contact
          end
        end

        def resource_relational_fields
          RELATIONAL_FIELDS
        end
    end
  end
end
