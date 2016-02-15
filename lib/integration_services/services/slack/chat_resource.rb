module IntegrationServices::Services
  module Slack
    class ChatResource < SlackResource

      def post_message body_hash
        token = body_hash.delete("token") || slack_token
        url = "#{server_url}/chat.postMessage"
        
        body = {
          :as_user => false,
          :link_names => 1,
          :unfurl_links => false,
          :unfurl_media => false,
          :token => token,
          :username => USER_NAME,
          :icon_url => ICON_URL
        }

        body.merge!(body_hash)

        response = http_post(url) do |req|
          req.body = body.to_query
          req.headers['Content-Type'] = "application/x-www-form-urlencoded"
        end
        process_response(response, 200) do |json_response|
          return json_response
        end
      end

    end

  end
end
