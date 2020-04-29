module IntegrationServices::Services
  module Shopify
    class ShopifyShopResource < IntegrationServices::Services::Shopify::ShopifyGenericResource
      
      def get_shop_info
        request_url = if Account.current.shopify_api_revamp_enabled?
          "#{server_url}/admin/#{SHOPIFY_API_VERSION}/shop.json"
        else
          "#{server_url}/admin/shop.json"
        end
        response = http_get request_url
        process_response(response, 200) do |shop_info|
          return {} if shop_info["shop"].blank?
          result = { name: shop_info["shop"]["name"] }
          return result
        end
      end

    end
  end
end