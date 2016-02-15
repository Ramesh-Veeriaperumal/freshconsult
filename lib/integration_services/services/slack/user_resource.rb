module IntegrationServices::Services
  module Slack
    class UserResource < SlackResource

      def list
        url = "#{server_url}/users.list?token=#{slack_token}"
        response = http_get(url)
        process_response(response, 200) do |json_response|
          return json_response
        end
      end

    end
  end
end
