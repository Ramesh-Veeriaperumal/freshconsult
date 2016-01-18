module IntegrationServices::Services
  module Slack
    class ChannelResource < SlackResource

      def list
        channel_url = "#{server_url}/channels.list"
        response = http_get(channel_url, {:token => slack_token })
        process_response(response, 200) do |json_response|
          return json_response["channels"].map {|channel| { "name" => "##{channel["name"]}", "id"   => channel["id"] } }
        end
      end

    end
  end
end
