module Ml
  class Bot
    class << self
      def update_ml(bot)
        begin
          response = RestClient::Request.execute(
            method: :post,
            url: BOT_CONFIG[:ml_onboarding_url],
            payload: ml_request_body(bot),
            timeout: 5,
            headers: {
              'Content-Type' => 'application/json',
              'Authorization' => BOT_CONFIG[:ml_authorization_key]
            }
          )
        rescue RestClient::RequestFailed, RestClient::ResourceNotFound, RestClient::RequestTimeout => e
          return e.response
        end
        JSON.parse(response)['result']['success']
      end

      def ml_request_body(bot)
        {
          bot_id: bot.external_id,
          account_id: bot.account_id,
          portal_id: bot.portal_id,
          category_list: bot.solution_category_metum_ids,
          product_name: 'Freshdesk'
        }.to_json
      end
    end
  end
end
