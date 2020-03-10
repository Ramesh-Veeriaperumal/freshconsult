module WidgetAuthentication
  include Helpdesk::Permission::User

  USER_ATTRIBUTES_TO_UPDATE = [:name].freeze
  BOOTSTRAP_CONTROLLER = 'bootstrap'.freeze

  attr_accessor :jwt_auth

  def widget_token_authentication

    auth_token = request.env['HTTP_X_WIDGET_AUTH']

    if auth_token.blank?
      return auth_token_required? ? render_request_error(:x_widget_auth_required, 400) : true
    end

    @jwt_auth = JWTAuthentication.new(source: 'help_widget', token: auth_token, secret_key: Account.current.help_widget_secret).authenticate
    return render_custom_errors(jwt_auth, true) if jwt_auth.errors.present?

    unless has_login_permission?(jwt_auth.payload[:email])
      return render_request_error(:action_restricted, 403, action: 'login', reason: 'domain/user is restricted in Admin')
    end

    set_user
    check_and_update_user
  end

  private

    def set_user
      @user = Account.current.user_emails.user_for_email(jwt_auth.payload[:email])
      @user.try(:make_current) if set_current_user?
    end

    def check_and_update_user
      if @user.blank? && cname != BOOTSTRAP_CONTROLLER
        render_request_error(:absent_in_db, 404, resource: 'user', attribute: 'email')
      elsif @user.present?
        return render_request_error(:invalid_user, 403, id: @user.id, name: @user.name) unless @user.valid_user?

        update_user_details if cname == BOOTSTRAP_CONTROLLER
      end
    end

    def update_user_details
      USER_ATTRIBUTES_TO_UPDATE.each do |user_attr|
        next if @user.safe_send(user_attr) == jwt_auth.payload[user_attr]

        @user.send("#{user_attr}=", jwt_auth.payload[user_attr])
      end
      @user.active = true
      @user.save!
    end

    def auth_token_required?
      false
    end

    def set_current_user?
      true
    end
end
