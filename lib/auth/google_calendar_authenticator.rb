class Auth::GoogleCalendarAuthenticator < Auth::Authenticator

  def after_authenticate(params)
    config_params = {
      'app_name'      => "#{@app.name}",
      'refresh_token' => "#{@omniauth.credentials.refresh_token}",
      'oauth_token'   => "#{@omniauth.credentials.token}"
    }

    set_redis_keys(config_params, 300)
    @result.redirect_url = get_redirect_url
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider(
      :google_oauth2,
      Integrations::OAUTH_CONFIG_HASH["google_oauth2"]["consumer_token"],
      Integrations::OAUTH_CONFIG_HASH["google_oauth2"]["consumer_secret"],
      :scope        => "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email",
      :prompt       => "select_account consent", #we'll get refresh_token only when consent is included!
      :access_type  => "offline",
      :redirect_uri => "#{AppConfig['integrations_url'][Rails.env]}/auth/google_calendar/callback",
      :name         => "google_calendar")
  end

  private

    def get_redirect_url
      "#{@portal_url}/integrations/user_credentials/oauth_install/google_calendar?user_auth=1"
    end

    def set_redis_keys(config_params, expire_time)
      key_options = { :account_id => @origin_account.id, :provider => @app.name, :user_id => @user_id }
      key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_USER_CRED_REDIRECT_OAUTH, key_options)
      Redis::KeyValueStore.new(key_spec, config_params.to_json, {:group => :integration, :expire => expire_time}).set_key
    end

end

