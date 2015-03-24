require 'omniauth/strategies/oauth2'
module OmniAuth
  module Strategies
    class Slack < OmniAuth::Strategies::OAuth2

      option :name, "slack"

      option :client_options, {
        site: "https://slack.com",
        token_url: "/api/oauth.access"
      }
    end
  end
end
