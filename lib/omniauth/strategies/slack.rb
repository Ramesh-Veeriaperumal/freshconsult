require 'omniauth/strategies/oauth2'

module OmniAuth
  module Strategies
    class Slack < OmniAuth::Strategies::OAuth2

      option :name, 'slack'

      option :authorize_options, [:scope,:team]

      def authorize_params
        super.tap do |params|
          params[:scope] = scope
          %w[team].each do |v|
            if request.params[v]
              params[v.to_sym] = request.params[v]
              params[:scope].slice! "commands,bot"
            end
          end
        end
      end

      def scope
        "commands,bot,channels:read,chat:write:bot,identify,groups:read,im:write,im:history,groups:history,channels:history,users:read,im:read"
      end


      option :client_options, {
        site: 'https://slack.com',
        token_url: '/api/oauth.access'
      }

      def full_host
        AppConfig['integrations_url'][Rails.env]
      end

      extra do 
        {
          raw_info: {
            bot_info: bot_info
          }
        }
      end

      def bot_info
        return {} unless access_token.params.key? 'bot'
        access_token.params['bot']
      end

    end
  end
end