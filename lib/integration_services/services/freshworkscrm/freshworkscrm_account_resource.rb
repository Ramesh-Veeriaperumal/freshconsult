# frozen_string_literal: false

module IntegrationServices::Services
  module Freshworkscrm
    class FreshworkscrmAccountResource < FreshworkscrmResource
      RELATIONAL_FIELDS = { 'industry_type_id' => ['industry_type', 'industry_types'],
                            'business_type_id' => ['business_type', 'business_types'],
                            'owner_id' => ['owner', 'users'], 'territory_id' => ['territory', 'territories'],
                            'parent_sales_account_id' => ['parent_sales_account', 'parent_sales_accounts'],
                            'creater_id' => ['creater', 'users'], 'updater_id' => ['updater', 'users'] }.freeze

      def fetch_fields
        request_url = "#{server_url}/settings/sales_accounts/fields.json"
        response = http_get request_url
        process_response(response, 200, &format_fields_block)
      end

      def get_selected_fields(fields, value)
        return { 'sales_accounts' => [], 'type' => 'sales_account' } if value[:company].blank? && value[:email].blank?

        account_response = nil
        if value[:company].present?
          account_response = filter_by_name value[:company]
        elsif value[:email].present?
          account_response = filter_by_email value[:email]
        end
        return { 'sales_accounts' => [], 'type' => 'sales_account' } if account_response.blank? || account_response['sales_accounts'].blank?

        account_id = account_response['sales_accounts'].first['id']
        url = "#{server_url}/sales_accounts/#{account_id}.json"
        fields = fields.split(',')
        relational_fields = fields & RELATIONAL_FIELDS.keys
        request_url = if relational_fields.present?
                        include_resources = relational_fields.map do |relational_field|
                          RELATIONAL_FIELDS[relational_field].first
                        end
                        encode_path_with_params url, include: include_resources.join(',')
                      else
                        url
                      end
        response = http_get request_url
        process_response(response, 200) do |account|
          return process_result(account, fields, relational_fields, 'sales_account')
        end
      end

      def filter_by_name(name)
        request_url = "#{server_url}/filtered_search/sales_account"
        filters = [construct_filter('name', 'is_in', name)]
        request_body = filter_request_body filters
        response = http_post request_url, request_body.to_json
        process_response(response, 200) do |account|
          return account
        end
      end

      def filter_by_email(email)
        request_url = "#{server_url}/filtered_search/contact"
        filters = [construct_filter('contact_email.email', 'is_in', email)]
        request_body = filter_request_body filters, 'sales_account'
        response = http_post request_url, request_body.to_json
        process_response(response, 200) do |account|
          return { 'sales_accounts' => Array.wrap(account['sales_accounts']) }
        end
      end

      def resource_relational_fields
        RELATIONAL_FIELDS
      end
    end
  end
end
