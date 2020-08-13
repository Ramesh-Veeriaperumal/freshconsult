module IntegrationServices::Services
  module Slack
    class SlackResource < IntegrationServices::GenericResource

      USER_NAME = "Freshdesk"

      ICON_URL = "https://d1hashle7dv0hm.cloudfront.net/integrations/slack/3702689370_48.png"

      def faraday_builder(b)
        super
        b.use FaradayMiddleware::FollowRedirects, limit: 3
      end

      def process_response(response, *success_codes, &block)
        @logger.debug("Slack Logger : STATUS=#{response.status} BODY=#{response.body} ")
        if success_codes.include?(response.status) && response.body.present?
            temp_response = parse(response.body)
            yield temp_response if temp_response["ok"]
        elsif response.status.between?(400, 499)
          error_response = parse(response.body)
          raise RemoteError, "Error message: #{error_response['error']}", response.status.to_s
        end
        raise RemoteError, "Unhandled error: STATUS=#{response.status} BODY=#{response.body}"
      end

      def server_url
        "https://slack.com/api"
      end

      def slack_token
        @slack_token ||= @service.configs["oauth_token"]
      end

      def bot_token
        @bot_token ||= @service.configs["bot_token"]
      end

    end
  end
end
