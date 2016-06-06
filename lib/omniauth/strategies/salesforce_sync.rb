module OmniAuth
  module Strategies
    class SalesforceSync < OmniAuth::Strategies::OAuth2

      option :name, 'salesforce_sync'
      option :client_options, {
        :site          => 'https://login.salesforce.com',
        :authorize_url => '/services/oauth2/authorize',
        :token_url     => '/services/oauth2/token'
      }
      option :authorize_options, [
        :scope,
        :display,
        :immediate,
        :state,
        :prompt,
        :redirect_uri,
        :login_hint
      ]

      def auth_hash
        signed_value = access_token.params['id'] + access_token.params['issued_at']
        raw_expected_signature = OpenSSL::HMAC.digest('sha256', options.client_secret.to_s, signed_value)
        expected_signature = Base64.strict_encode64 raw_expected_signature
        signature = access_token.params['signature']
        fail! "Salesforce user id did not match signature!" unless signature == expected_signature
        super
      end

      uid { raw_info['id'] }

      info do
        {
          'name'            => raw_info['display_name'],
          'email'           => raw_info['email'],
          'nickname'        => raw_info['nick_name'],
          'first_name'      => raw_info['first_name'],
          'last_name'       => raw_info['last_name'],
          'location'        => '',
          'description'     => '',
          'image'           => raw_info['photos']['thumbnail'] + "?oauth_token=#{access_token.token}",
          'phone'           => '',
          'urls'            => raw_info['urls']
        }
      end

      credentials do
        hash = {'token' => access_token.token}
        hash.merge!('instance_url' => access_token.params["instance_url"])
        hash.merge!('refresh_token' => access_token.refresh_token) if access_token.refresh_token
        hash
      end

      def raw_info
        access_token.options[:mode] = :header
        @raw_info ||= access_token.post(access_token['id']).parsed
      end

      extra do
        raw_info.merge({
          'instance_url' => access_token.params['instance_url'],
          'pod' => access_token.params['instance_url'],
          'signature' => access_token.params['signature'],
          'issued_at' => access_token.params['issued_at']
        })
      end
    end
  end
end