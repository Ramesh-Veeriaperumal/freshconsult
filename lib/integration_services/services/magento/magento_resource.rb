module IntegrationServices::Services
  module Magento
    class MagentoResource < IntegrationServices::GenericResource

      def faraday_builder(b)
        super
        b.use FaradayMiddleware::OAuth, oauth_data
      end

      def oauth_data
        position = @service.payload[:position]
        shop_data = @service.configs["shops"][position]
        {
          :consumer_key => shop_data["consumer_token"],
          :consumer_secret => shop_data["consumer_secret"],
          :token => shop_data["oauth_token"],
          :token_secret => shop_data["oauth_token_secret"]
        }
      end
      
      def process_response(response, *success_codes)
        if success_codes.include?(response.status)
          {:status => 200, :message => parse(response.body)}
        elsif response.status.between?(400, 499)
          {:status => 400, :message => "Token invalid. Reinstall application."}
        else
          {:status => 400, :message => "Unknown error. Try after sometime."}
        end
      end

    end
  end
end
