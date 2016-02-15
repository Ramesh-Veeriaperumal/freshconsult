module IntegrationServices::Services
  module Slack
    class GroupResource < SlackResource

      def list
        group_url = "#{server_url}/groups.list"
        groups_response = http_get(group_url, {:token => slack_token})
        process_response(groups_response, 200) do |json_response|
          return json_response["groups"].map{|group| { "name" => "##{group["name"]}", "id"  => group["id"] } }
        end
      end

    end
  end
end
