module IntegrationServices::Services
  module Shopify
    class ShopifyRefundResource < IntegrationServices::Services::Shopify::ShopifyGenericResource

      def refund_full_order(order_id)
        return {} if order_id.blank?
        order_resource = IntegrationServices::Services::Shopify::ShopifyOrderResource.new(@service, @store, @token)
        order = order_resource.get_order(order_id)
        return {} if order.blank?
        presentment_currency = order["presentment_currency"]
        raise "Cannot refund" if order["can_refund_full_order"].blank?
        refund_line_items = order["line_items"].map do |item|
          { line_item_id: item["id"], quantity: item["quantity"]}
        end
        refund_calculate_hash = {
          "refund": {
            "currency": presentment_currency, 
            "shipping": {
              "full_refund": true
            },
            "refund_line_items": refund_line_items,
            "location_id": order['location_id']
          }
        }
        refund_values = {}
        refund_calculate_url = "#{server_url}/admin/#{SHOPIFY_API_VERSION}/orders/#{order_id}/refunds/calculate.json"
        response = http_post refund_calculate_url, refund_calculate_hash.to_json
        process_response(response, 200) do |refund|
          refund_values = refund
        end
        refund_hash = {
          "refund": {
            "currency": presentment_currency,
            "shipping": {
              "full_refund": true
            },
            "refund_line_items": refund_line_items,
            "location_id": order['location_id']
          }
        }
        refund_values["refund"]["transactions"].each do |t|
          t["kind"] = "refund"
        end
        refund_hash[:refund][:transactions] = refund_values["refund"]["transactions"]
        refund_url = "#{server_url}/admin/#{SHOPIFY_API_VERSION}/orders/#{order_id}/refunds.json"
        response = http_post refund_url, refund_hash.to_json
        process_response(response, 201) do |refund|
          return refund
        end
      end

      def refund_line_item(order_id, line_item_id)
        return {} if order_id.blank?
        order_resource = IntegrationServices::Services::Shopify::ShopifyOrderResource.new(@service, @store, @token)
        order = order_resource.get_order(order_id)
        return {} if order.blank?
        presentment_currency = order["presentment_currency"]
        quantity = 0
        order["line_items"].each do |item|
          if item["id"] == line_item_id
            quantity = item["quantity"]
            raise "Cannot refund" if item["can_refund"].blank?
          end
        end
        refund_calculate_hash = {
          "refund": {
            "currency": presentment_currency,
            "location_id": order['location_id'],
            "refund_line_items": [
              {
                "line_item_id": line_item_id,
                "quantity": quantity
              }
            ]
          }
        }
        refund_values = {}
        refund_calculate_url = "#{server_url}/admin/#{SHOPIFY_API_VERSION}/orders/#{order_id}/refunds/calculate.json"
        response = http_post refund_calculate_url, refund_calculate_hash.to_json
        process_response(response, 200) do |refund|
          refund_values = refund
        end
        refund_hash = {
          "refund": {
            "currency": presentment_currency,
            "location_id": order['location_id'],
            "refund_line_items": [
              {
                "line_item_id": line_item_id,
                "quantity": quantity
              }
            ]
          }
        }
        refund_values["refund"]["transactions"].each do |t|
          t["kind"] = "refund"
        end
        refund_hash[:refund][:transactions] = refund_values["refund"]["transactions"]
        refund_url = "#{server_url}/admin/#{SHOPIFY_API_VERSION}/orders/#{order_id}/refunds.json"
        response = http_post refund_url, refund_hash.to_json
        process_response(response, 201) do |refund|
          return refund
        end
      end
    end
  end
end