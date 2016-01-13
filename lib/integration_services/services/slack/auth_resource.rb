module IntegrationServices::Services
  module Slack
    class AuthResource < SlackResource

      def test token
        url = "#{server_url}/auth.test?token=#{token}"
        response = http_get(url)
        process_response(response, 200) do |json_response|
          return json_response["ok"].present?
        end
      end

    end
  end
end
