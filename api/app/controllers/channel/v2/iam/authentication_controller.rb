module Channel::V2::Iam
  class AuthenticationController < ApiApplicationController
    skip_before_filter :load_object, :check_privilege

    def show
      fetch_current_user
      return render_request_error(:invalid_credentials, 401) if @current_user.blank?

      jwt_token = construct_jwt(@current_user)
      response.headers['Authorization'] = "Token #{jwt_token}"
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
          UserId: user.id.to_s,
          ProductAccId: Account.current.id.to_s,
          Product: 'freshdesk',
          Permissions: user.privileges.to_s,
          iat: Time.now.to_i,
          exp: Time.now.to_i + ::Iam::IAM_CONFIG['expiry'].to_i
        }
        payload[:OrgId] = Account.current.organisation_account_mapping.organisation_id if Account.current.organisation_account_mapping.present?
        private_key = OpenSSL::PKey::RSA.new(File.read('config/cert/iam.pem'), ::Iam::IAM_CONFIG['password'])
        JWT.encode(payload, private_key, 'RS256')
      end
  end
end
