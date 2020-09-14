module IntegrationServices::Services
  module Shopify
    class ShopifyOrderResource < IntegrationServices::Services::Shopify::ShopifyGenericResource

      def get_recent_orders(customer_id)
        return {} if customer_id.blank?

        request_url = "#{server_url}/admin/#{SHOPIFY_API_VERSION}/orders.json?limit=5&order=created_at%20desc&customer_id=#{customer_id}&status=any"
        response = http_get request_url
        process_response(response, 200) do |orders|
          return {} if orders["orders"].blank?
          result = []
          orders["orders"].each do |order|
            order = validate_order(order)
            result << format_order(order)
          end
          return result
        end
      end

      def get_order(order_id)
        return {} if order_id.blank?

        request_url = "#{server_url}/admin/#{SHOPIFY_API_VERSION}/orders/#{order_id}.json"
        response = http_get request_url
        process_response(response, 200) do |order|
          return {} if order["order"].blank?
          return validate_order(order["order"])
        end
      end

      def cancel_order(order_id)
        return {} if order_id.blank?

        request_url = "#{server_url}/admin/#{SHOPIFY_API_VERSION}/orders/#{order_id}/cancel.json"
        response = http_post request_url
        process_response(response, 200) do |result|
          return result
        end
      end

      private

      def validate_order(order)
        can_cancel = true
        can_refund_full_order = true
        refunded_line_items = []
        if order["cancelled_at"].present? || order["fulfillment_status"].present?
          can_cancel = false
        end
        if order["refunds"].present?
          can_refund_full_order = false
          order["refunds"].each do |refund|
            break if refund["refund_line_items"].blank?
            refund["refund_line_items"].each do |line_item|
              refunded_line_items << line_item["line_item_id"]
            end
          end
        end
        if order["cancelled_at"].present?
          can_refund_full_order = false
        end
        order["can_cancel"] = can_cancel
        order["can_refund_full_order"] = can_refund_full_order
        order["line_items"].each do |line_item|
          if order["cancelled_at"].present? || refunded_line_items.include?(line_item["id"])
            line_item["can_refund"] = false
          else
            line_item["can_refund"] = true
          end
        end
        order
      end

      def format_order(order)
        order['admin_url'] = "#{server_url}/admin/orders/#{order["id"]}"
        required_keys = [
          'currency', 'customer', 'email', 'financial_status',
          'fulfillment_status', 'id', 'line_items', 'order_number', 'total_price',
          'cancelled_at', 'can_cancel', 'can_refund_full_order', 'admin_url', 'name'
        ]
        order.select {|key| required_keys.include?(key) }
      end
    end
  end
end