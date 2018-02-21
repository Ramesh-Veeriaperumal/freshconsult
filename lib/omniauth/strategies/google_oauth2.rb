module OmniAuth
  module Strategies
    class GoogleOauth2 < OmniAuth::Strategies::OAuth2


      DEFAULT_SCOPE = "userinfo.email,userinfo.profile"
      BASE_SCOPE_URL = "https://www.googleapis.com/auth/"

      option :name, 'google_oauth2'
      option :authorize_options, [:scope, :access_type, :state, :hd, :redirect_uri, :prompt]
      option :provider_ignores_state, true

      option :client_options, {
        :site          => 'https://accounts.google.com',
        :authorize_url => '/o/oauth2/auth',
        :token_url     => '/o/oauth2/token'
      }

      def authorize_params
        super.tap do |params|
          options[:authorize_options].each do |k|
            params[k] = request.params[k] unless [nil, ''].include?(request.params[k])
          end
          scopes = (params[:scope] || DEFAULT_SCOPE).split(",")
          scopes.map! { |s| s =~ /^https?:\/\// ? s : "#{BASE_SCOPE_URL}#{s}" }
          params[:scope] = scopes.join(' ')
          # This makes sure we get a refresh_token.
          # http://googlecode.blogspot.com/2011/10/upcoming-changes-to-oauth-20-endpoint.html
          params[:access_type] = 'offline' if params[:access_type].nil?
          # Override the state per request
          session['omniauth.state'] = params[:state] if request.params['state']
        end
      end

      uid{ raw_info['id'] || verified_email }

      info do
        prune!({
          :name       => raw_info['name'],
          :email      => verified_email,
          :first_name => raw_info['given_name'],
          :last_name  => raw_info['family_name'],
          :image      => raw_info['picture']
        })
      end

      extra do
        hash = {}
        hash[:raw_info] = raw_info unless skip_info?
        prune! hash
      end

      def raw_info
        @raw_info ||= access_token.get('https://www.googleapis.com/oauth2/v1/userinfo').parsed
      end

      private

        def callback_url
          options[:redirect_uri] || (full_host + script_name + callback_path)
        end

        def request_has_approval_prompt
          request.env && request.params && request.params['approval_prompt']
        end

        def prune!(hash)
          hash.delete_if do |_, value|
            prune!(value) if value.is_a?(Hash)
            value.nil? || (value.respond_to?(:empty?) && value.empty?)
          end
        end

        def verified_email
          raw_info['verified_email'] ? raw_info['email'] : nil
        end

    end
  end
end
