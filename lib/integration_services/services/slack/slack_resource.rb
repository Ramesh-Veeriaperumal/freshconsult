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
        response_status = response.status
        response_body = response.body
        @logger.debug("Slack Logger : STATUS=#{response_status} BODY=#{response_body} ")
        if success_codes.include?(response_status) && response_body.present?
          temp_response = parse(response_body)
          yield temp_response if temp_response['ok']
        elsif response_status.between?(400, 499)
          error_response = parse(response_body)
          raise RatelimitError, 'Error message: ratelimited' if response_status == 429

          raise RemoteError, "Error message: #{error_response['error']}", response_status.to_s
        end
        raise TokenRevokedError, 'Error message: token_revoked' if token_revoked?(response_body)

        raise RemoteError, "Unhandled error: STATUS=#{response_status} BODY=#{response_body}"
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

      def token_revoked?(response_body)
        response_body.present? && parse(response_body)['error'] == 'token_revoked'
      end
    end
  end
end
