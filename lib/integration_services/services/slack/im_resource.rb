module IntegrationServices::Services
  module Slack
    class ImResource < SlackResource

      def history token
        channel = @service.payload[:act_hash][:channel_id]
        last_message_time = @service.payload[:act_hash][:time]
        url = channel_api_url
        response = http_get(url, {:token=>token, :channel=>channel, :latest=>last_message_time,
                                    :count=>200, :inclusive=> 1})
        process_response(response, 200) do |json_response|
          return json_response["messages"].reverse
        end
      end

      def channel_api_url
        if @service.payload[:act_hash][:channel_name] == "privategroup"
          url = "#{server_url}/groups.history"
        elsif @service.payload[:act_hash][:channel_name] == "directmessage"
          url = "#{server_url}/im.history"
        else
          url = "#{server_url}/channels.history"
        end
        url
      end

      def open user_id
        url = "#{server_url}/im.open"
        im_response = http_get(url, {:token => bot_token.present? ? bot_token : slack_token, :user => user_id})
        process_response(im_response, 200) do |json_response|
          return json_response["channel"]["id"]
        end
      end

      def list token, channel_id
        url = "#{server_url}/im.list"
        im_response = http_get(url, {:token => token})
        process_response(im_response, 200)  do |json_response|
          json_response["ims"].each do |dm|
            return dm["user"] if dm["id"] == channel_id
          end
        end
      end

    end
  end
end
