require 'omniauth/strategies/oauth2'

module OmniAuth
  module Strategies
    class Slack < OmniAuth::Strategies::OAuth2

      option :name, 'slack'

      option :authorize_options, [:scope]

      option :authorize_params, {
        scope: "channels:read,chat:write:bot,identify,chat:write:user,groups:read,im:write,im:history,users:read"
      }

      option :client_options, {
        site: 'https://slack.com',
        token_url: '/api/oauth.access'
      }

      def full_host
        AppConfig['integrations_url'][Rails.env]
      end

    end
  end
end