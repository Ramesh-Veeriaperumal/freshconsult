module IntegrationServices::Services
  module Slack
    class SlackResource < IntegrationServices::GenericResource

      USER_NAME = "Freshdesk"

      # Change this url to the url of the uploaded production app account in slack.
      ICON_URL = "https://s3-us-west-2.amazonaws.com/slack-files2/bot_icons/2015-02-12/3702689370_48.png"

      def faraday_builder(b)
        super
        b.use FaradayMiddleware::FollowRedirects, limit: 3
      end

      def process_response(response, *success_codes, &block)
        if success_codes.include?(response.status) && response.body.present?
            temp_response = parse(response.body)
            yield temp_response if temp_response["ok"]
        elsif response.status.between?(400, 499)
          error = parse(response.body)
          raise RemoteError, "Error message: #{error.first['message']}", response.status.to_s
        end
        raise RemoteError, "Unhandled error: STATUS=#{response.status} BODY=#{response.body}"
      end

      def server_url
        "https://slack.com/api"
      end

      def slack_token
        @slack_token ||= @service.configs["oauth_token"]
      end

    end
  end
end
