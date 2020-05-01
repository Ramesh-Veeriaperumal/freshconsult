module IntegrationServices::Services
  module Shopify
    class ShopifyGenericResource < IntegrationServices::GenericResource
      SHOPIFY_API_VERSION = "api/2020-01"

      def initialize(service, store, token)
        super(service)
        @store = store
        @token = token
      end

      def faraday_builder(b)
        super
        b.headers["X-Shopify-Access-Token"] = @token
      end

      def server_url
        "https://#{@store[:shop_name]}"
      end

      def process_response(response, *success_codes, &block)
        if success_codes.include?(response.status)
          yield parse(response.body)
        elsif response.status.between?(400, 499)
          raise RemoteError, response.body, response.status.to_s
        else
          raise RemoteError, "Unhandled error: STATUS=#{response.status} BODY=#{response.body}"
        end
      end
    end
  end
end
