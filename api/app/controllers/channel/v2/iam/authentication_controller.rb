module Channel::V2::Iam
  class AuthenticationController < ApiApplicationController
    include Iam::AuthToken

    skip_before_filter :load_object, :check_privilege, :ensure_proper_protocol

    def authenticate
      fetch_current_user
      return render_request_error(:invalid_credentials, 401) if @current_user.blank?

      response.headers['Authorization'] = construct_jwt(@current_user)
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
  end
end
