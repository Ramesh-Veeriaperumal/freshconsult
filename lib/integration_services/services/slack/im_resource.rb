module IntegrationServices::Services
  module Slack
    class ImResource < SlackResource

      def history token
        channel = @service.payload[:act_hash][:channel_id]
        last_message_time = @service.payload[:act_hash][:time]
        url = "#{server_url}/im.history"
        response = http_get(url, {:token=>token, :channel=>channel, :latest=>last_message_time,
                                    :count=>200, :inclusive=> 1})
        process_response(response, 200) do |json_response|
          return json_response["messages"].reverse
        end
      end

      def open user_id
        url = "#{server_url}/im.open"
        im_response = http_get(url, {:token => slack_token, :user => user_id})
        process_response(im_response, 200) do |json_response|
          return json_response["channel"]["id"]
        end
      end

    end
  end
end
