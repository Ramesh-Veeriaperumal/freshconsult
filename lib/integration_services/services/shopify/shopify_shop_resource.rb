module IntegrationServices::Services
  module Shopify
    class ShopifyShopResource < IntegrationServices::Services::Shopify::ShopifyGenericResource
      
      def get_shop_info
        request_url = "#{server_url}/admin/#{SHOPIFY_API_VERSION}/shop.json"
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