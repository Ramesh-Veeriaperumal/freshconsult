require 'omniauth/strategies/oauth2'

module OmniAuth
  module Strategies
    class OutlookContacts < OmniAuth::Strategies::OAuth2

      option :name, 'outlook_contacts'

      option :client_options, {
        :site => 'https://login.microsoftonline.com',
        :authorize_url => '/common/oauth2/v2.0/authorize',
        :token_url => '/common/oauth2/v2.0/token'
      }

      option :authorize_params, {
        scope: "openid email profile offline_access https://outlook.office.com/contacts.readwrite"
      }

      uid { raw_info["Id"] }

      info do
        {
          :email => raw_info["EmailAddress"],
          :display_name => raw_info["DisplayName"]
        }
      end

      extra do
        {
          "raw_info" => raw_info
        }
      end

      def raw_info
        @raw_info ||= access_token.get("https://outlook.office.com/api/v2.0/me/").parsed
      end
      
    end
  end
end
