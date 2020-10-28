class Auth::FacebookAuthenticator < Auth::Authenticator
  include Integrations::FacebookLoginHelper
  include Helpdesk::Permission::User

  def after_authenticate(params)
    user_account.make_current
    native_mobile_flag = nmobile?(params)
    begin
      state = "/facebook" if portal_type.present?
      unless user_account.blank?
        @current_user = user_account.user_emails.user_for_email(fb_email) if fb_email.present?
        @auth = Authorization.find_from_hash(@omniauth, user_account.id)
        @current_user = user_account.all_users.find_by_fb_profile_id(fb_profile_id) if @current_user.blank? and fb_profile_id.present?
        return facebook_invalid_redirect if !@current_user and !has_login_permission?(fb_email, user_account)
        if create_user_for_sso(native_mobile_flag)
          set_redis_for_sso(user_account.id, @current_user.id, @omniauth['provider'])
          @result.redirect_url = get_redirect_url(state, native_mobile_flag)
        else
          @result.redirect_url = @portal_url
        end
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      @result.redirect_url = @portal_url
    end
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider(
      :facebook,
      FacebookConfig::APP_ID, #facebook is in facebook.yml
      FacebookConfig::SECRET_KEY, #facebook is in facebook.yml
      :setup => lambda { |env|
        unless env["PATH_INFO"].split("/")[3] == "callback"
          raise "Facebook Signin Feature is not enabled for this account." unless facebook_signin_enabled?(env['QUERY_STRING'])
          env['omniauth.strategy'].options[:state] = construct_state_params(env) 
        end
      },
      :authorize_options => [:scope, :display, :state, :redirect_uri],
      :redirect_uri => "#{AppConfig['integrations_url'][Rails.env]}/auth/facebook/callback",
      :name => "facebook")
  end

  private
  def facebook_signin_enabled?(query_string)
    Rails.logger.info "Facebook Authenticator - Query string = #{query_string.inspect}"
      query = Rack::Utils.parse_query(query_string)
    Rails.logger.info "Facebook Authenticator - Query = #{query.inspect}"
      account_id = Rack::Utils.parse_query(query["origin"])["id"]
    Rails.logger.info "Facebook Authenticator - Account ID = #{account_id}"
      flag = false
      Sharding.select_shard_of(account_id) do
        account = Account.find(account_id)
        account.make_current
        flag = account.features?(:facebook_signin)
      end
      flag
  end


    def get_redirect_url state, native_mobile_flag
      fb_url(native_mobile_flag) + "#{state}/sso/login?provider=facebook&uid=#{uid}&s=#{random_hash}&at=#{csrf_token_from_state_params}"
    end

    def fb_url native_mobile_flag
      url = portal_type.present? ? "#{user_account.url_protocol}://#{user_account.full_domain}" : @portal_url
      url = "https://#{user_account.full_domain}" if native_mobile_flag #always use https for requests from mobile app.
      return url
    end

    def construct_state_params env
      query_string = Rack::Utils.parse_query(env['QUERY_STRING'])
      origin = Rack::Utils.parse_query(query_string['origin'])
      account_id = Rack::Utils.parse_query(query_string['origin'])['id']
      ecrypted_msg = get_ecrypted_msg(account_id, env['HTTP_HOST'])
      "portal_type%3D#{origin['portal_type']}%26identifier%3D#{ecrypted_msg}%26portal_domain%3D#{env['HTTP_HOST']}%26at%3D#{origin['token']}"
    end

    def facebook_invalid_redirect
      @result.redirect_url = "#{@portal_url}/support/login?restricted_helpdesk_login_fail=true"
      @result.invalid_nmobile = true
      @result
    end
end
