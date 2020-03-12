module Channel::V2::Iam
  class AuthenticationController < ApiApplicationController
    skip_before_filter :load_object, :check_privilege, :ensure_proper_protocol

    PRIVATE_KEY = OpenSSL::PKey::RSA.new(File.read('config/cert/iam.pem'), ::Iam::IAM_CONFIG['password'])

    def authenticate
      fetch_current_user
      return render_request_error(:invalid_credentials, 401) if @current_user.blank?

      jwt_token = construct_jwt(@current_user)
      response.headers['Authorization'] = "Bearer #{jwt_token}"
    end

    private

      def fetch_current_user
        return if @current_user.present?

        if private_api?
          session_auth
        elsif current_account.launched?(:api_jwt_auth) && request.env['HTTP_AUTHORIZATION'] && request.env['HTTP_AUTHORIZATION'][/^Token (.*)/]
          ApiAuthLogger.log "FRESHID API version=V2, auth_type=JWT_TOKEN, a=#{current_account.id}"
          # authenticate using JWT token
          authenticate_with_http_token do |token|
            @current_user = FdJWTAuth.new(token).decode_jwt_token
          end
        else
          basic_auth
        end
      end

      def private_api?
        return true if request.params['url'].starts_with?('/api/_/')

        false
      end

      def construct_jwt(user)
        payload = {
          user_id: user.id.to_s,
          account_id: Account.current.id.to_s,
          product: 'freshdesk',
          account_domain: Account.current.full_domain,
          privileges: user.privileges.to_s,
          iat: Time.now.to_i,
          exp: Time.now.to_i + ::Iam::IAM_CONFIG['expiry'].to_i
        }
        payload[:type] = user.helpdesk_agent? ? 'agent' : 'contact'
        payload[:org_user_id] = user.freshid_authorization.uid if user.helpdesk_agent? && user.freshid_authorization.try(:provider) == 'freshid'
        payload[:org_id] = Account.current.organisation_account_mapping.organisation_id if Account.current.organisation_account_mapping.present?
        headers = {
          kid: ::Iam::IAM_CONFIG['kid'],
          typ: 'JWT',
          alg: 'RS256'
        }
        JWT.encode(payload, PRIVATE_KEY, 'RS256', headers)
      end
  end
end
