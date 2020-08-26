module IntegrationServices::Services
  module Freshworkscrm
    class FreshworkscrmDealResource < FreshworkscrmResource
      RELATIONAL_FIELDS = { 'deal_stage_id' => 'deal_stages', 'deal_reason_id' => 'deal_reasons',
                            'deal_type_id' => 'deal_types', 'owner_id' => 'users',
                            'campaign_id' => 'campaigns', 'deal_pipeline_id' => 'deal_pipelines',
                            'deal_product_id' => 'deal_products', 'deal_payment_status_id' => 'deal_payment_statuses',
                            'sales_account_id' => 'sales_accounts', 'territory_id' => 'territories' }.freeze

      def get_fields
        request_url = "#{server_url}/settings/deals/fields.json"
        response = http_get request_url
        process_response(response, 200, &format_fields_block)
      end

      def get_selected_fields(fields, value)
        return { 'deals' => [], 'type' => 'deal' } if value[:account_id].blank?

        deal_response = fetch_by_account_id value[:account_id]
        return { 'deals' => [], 'type' => 'deal' } if deal_response['deals'].blank?

        deal_response = integrated_remote_resource(value[:account_id], deal_response)
        return { 'deals' => [], 'type' => 'deal' } if deal_response['deals'].blank?

        deal_response = filter_deals_by_status(deal_response)
        fields = fields.split(',')
        relational_fields = fields & RELATIONAL_FIELDS.keys
        if relational_fields.present?
          deal_response['deals'].each do |deal|
            relational_fields.each do |relational_field|
              deal[relational_field] = get_relational_field relational_field, deal[relational_field], deal_response if deal[relational_field].present?
            end
          end
        end
        result = get_custom_fields('deals', fields, 'deals' => deal_response['deals'])
        result = { 'deals' => result['deals'], 'type' => 'deal' }
      end

      def sort_by_close_date(deals, field1, field2, limit)
        deals = deals.sort do |a, b|
          if a[field1[:name]] && b[field1[:name]]
            [date_time(a[field1[:name]], field1[:order]), date_time(a[field2[:name]], field2[:order])] <=> [ date_time(b[field1[:name]], field1[:order]), date_time(b[field2[:name]], field2[:order])]
          else
            [a[field1] ? -1 : 1, date_time(a[field2[:name]], field2[:order])] <=> [b[field1] ? -1 : 1, date_time(b[field2[:name]], field2[:order])]
          end
        end
        deals.first(limit)
      end

      def integrated_remote_resource(account_id, deal_response)
        link_status = nil
        linked_deal = nil
        if @service.payload[:ticket_id].present?
          integrated_resource = @service.installed_app.integrated_resources.where(local_integratable_id: @service.payload[:ticket_id], local_integratable_type: 'Helpdesk::Ticket').first
          link_status = false
          if integrated_resource.present?
            link_status = true
            deals = deal_response['deals']
            linked_deal = deals.detect do |deal|
              deal['id'].to_s == integrated_resource.remote_integratable_id
            end
            if linked_deal.present?
              linked_deal['link_status'] = link_status
              linked_deal['unlink_status'] = link_status
              deal_response['deals'] = [linked_deal]
              deal_response['linked'] = true
              return deal_response
            end
          end
          deal_response['deals'].each do |deal|
            deal['link_status'] = link_status
          end
        end
        deal_response
      end

      def filter_deals_by_status(deal_response, limit = 5)
        return deal_response if deal_response['linked']

        open_deals = deal_response['deals'].reject do |deal|
          deal['closed_date'].present?
        end
        deals = if open_deals.length >= limit
                  sort_by_close_date(open_deals, { name: 'expected_close', order: 'ASC' }, { name: 'created_at', order: 'ASC' }, limit)
                else
                  sorted_open_deals = sort_by_close_date(open_deals, { name: 'expected_close', order: 'ASC' }, { name: 'created_at', order: 'ASC' }, open_deals.length)
                  closed_deals = deal_response['deals'] - open_deals
                  sorted_open_deals + sort_by_close_date(closed_deals, { name: 'closed_date', order: 'DESC' }, { name: 'stage_updated_time', order: 'DESC' }, limit - open_deals.length)
                end
        deal_response['deals'] = deals
        deal_response
      end

      def date_time(datestring, order)
        date_integer = DateTime.parse(datestring).to_time.to_i
        date_integer *= -1 if order == 'DESC'
        date_integer
      end

      def get_relational_field(relational_field, field_id, deal_response)
        relational_field_attribute = RELATIONAL_FIELDS[relational_field]
        deal_response[relational_field_attribute].each do |deal_relational_option|
          return deal_relational_option['name'] || deal_relational_option['display_name'] if deal_relational_option['id'] == field_id
        end
        nil
      end

      def fetch_by_account_id(account_id)
        url = "#{server_url}/sales_accounts/#{account_id}.json"
        request_url = encode_path_with_params url, include: 'deals'
        response = http_get request_url
        process_response(response, 200) do |deals|
          return deals
        end
      end

      def find(id)
        url = "#{server_url}/deals/#{id}.json"
        response = http_get url
        process_response(response, 200, 404) do |deal|
          return deal
        end
      end

      def stage_dropdown_values
        request_url = "#{server_url}/selector/deal_stages"
        response = http_get request_url
        process_response(response, 200) do |deal_stages|
          deal_stages['deal_stages'].map do |deal_stage|
            [deal_stage['name'], deal_stage['id'].to_s]
          end
        end
      end

      def get_custom_fields(resource_type, fields, result)
        result[resource_type].each do |resource|
          resource_custom_fields = resource['custom_field']
          selected_custom_fields = resource_custom_fields.keys & fields if resource_custom_fields.present?
          if selected_custom_fields.present?
            selected_custom_fields.each do |selected_custom_field|
              resource[selected_custom_field] = resource_custom_fields[selected_custom_field]
            end
          end
        end
        result
      end

      def create(request_body)
        request_url = "#{server_url}/deals"
        response = http_post request_url, request_body.to_json
        process_response(response, 200) do |deal|
          return deal
        end
      end
    end
  end
end
