module Channel::V2::Iam
  class AuthenticationController < ApiApplicationController
    include Iam::AuthToken
    include HelperConcern

    skip_before_filter :load_object, :check_privilege, :ensure_proper_protocol

    skip_before_filter :ensure_proper_fd_domain, only: [:authenticate]

    before_filter :sanitize_params, :validate_body_params, :validate_user, only: [:iam_authenticate_token]

    def authenticate
      fetch_current_user
      return render_request_error(:invalid_credentials, 401) if @current_user.blank?

      response.headers['Authorization'] = construct_jwt_with_bearer(@current_user)
    end

    def iam_authenticate_token
      return render_request_error(:invalid_credentials, 401) unless Iam::IAM_CLIENT_SECRETS[params[:client_id]].include?(params[:client_secret])

      @token = {
                 access_token: construct_jwt(@current_user, params[:scope]),
                 token_type: BEARER,
                 expires_in: Iam::IAM_CONFIG['expiry']
               }
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
        return false if request.params['url'].blank?

        request.params['url'].starts_with?('/api/_/')
      end

      def validate_user
        return render_request_error(:invalid_credentials, 401) unless Account.current.users.exists?(params[:user_id])

        @current_user = Account.current.users.find(params[:user_id])
        if params[:scope].present?
          params[:scope].each do |privilege|
            return render_request_error(:access_denied, 403) unless @current_user.privilege?(privilege)
          end
        end
      end

      def validate_body_params
        validate_request(nil, params, nil)
      end

      def constants_class
        AuthenticationConstants
      end

      def sanitize_params
        params[:scope] = params[:scope].split(/\s*,\s*/).map(&:to_sym).uniq if params[:scope].present?
      end

      def valid_content_type?
        return url_encoded_form? if current_action?('iam_authenticate_token')

        super
      end
  end
end
