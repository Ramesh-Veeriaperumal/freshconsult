module Widget
  class BootstrapController < ApiApplicationController
    include WidgetConcern

    skip_before_filter :validate_filter_params

    SLAVE_ACTIONS = [].freeze
    USER_PAYLOAD_KEYS = [:name, :email, :timestamp].freeze

    def index
      create_user if @user.nil?
    end

    private

      def create_user
        @user = Account.current.users.new
        @user.active = true
        if @user.signup!({ user: jwt_auth.payload.slice(*USER_PAYLOAD_KEYS) }, nil, false)
          @user.make_current
        else
          render_request_error :unable_to_perform, 403
        end
      end

      def launch_party_name
        :help_widget_login
      end

      def auth_token_required?
        true
      end
  end
end
