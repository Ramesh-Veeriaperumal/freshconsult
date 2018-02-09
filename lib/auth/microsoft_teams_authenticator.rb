class Auth::MicrosoftTeamsAuthenticator < Auth::Authenticator
  APP_NAME = Integrations::Constants::APP_NAMES[:microsoft_teams]

  def after_authenticate(_params)
    access_token = @omniauth.credentials
    user_info = @omniauth.info
    uid = @omniauth.uid
    config_params = {
      'app_name' => @app.name.to_s,
      'user_id' => uid.to_s,
      'user_email' => (user_info['email']).to_s,
      'tenant_id' => (user_info['tenant_id']).to_s
    }
    set_redis_keys config_params, 3600
    @result.redirect_url = get_redirect_url
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider(
      :microsoft_graph,
      Integrations::OAUTH_CONFIG_HASH[APP_NAME]['consumer_token'],
      Integrations::OAUTH_CONFIG_HASH[APP_NAME]['consumer_secret'],
      scope: 'user.read',
      name: APP_NAME
    )
  end

  def get_redirect_url
    url = @state_params == 'agent' ? 'integrations/teams/authorize_agent' : 'integrations/teams/install'
    @falcon_enabled == 'true' ? "#{@portal_url}/a/#{url}" : "#{@portal_url}/#{url}"
  end
end
