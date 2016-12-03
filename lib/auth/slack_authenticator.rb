class Auth::SlackAuthenticator < Auth::Authenticator

  def after_authenticate(params)
    access_token = @omniauth.credentials
    bot_token = @omniauth.extra.raw_info.bot_info
    config_params = {
      'app_name' => "#{@app.name}",
      'oauth_token' => "#{access_token.token}",
      'bot_token' => "#{bot_token.bot_access_token}"
    }
    set_redis_key config_params, 3600
    @result.redirect_url = get_redirect_url
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider(:slack, Integrations::OAUTH_CONFIG_HASH["slack"]["consumer_token"],
                      Integrations::OAUTH_CONFIG_HASH["slack"]["consumer_secret"])
  end

  def get_redirect_url
    if @state_params == "agent"
      return "#{@portal_url}/integrations/slack_v2/add_slack_agent"   
    end
    "#{@portal_url}/integrations/slack_v2/new"
  end

  def set_redis_key(config_params, expire_time = nil)
    key_options = { :account_id => @origin_account.id, :provider => @app.name, :user_id => @user_id}
    key_spec = Redis::KeySpec.new(Redis::RedisKeys::SSO_AUTH_REDIRECT_OAUTH, key_options)
    Redis::KeyValueStore.new(key_spec, config_params.to_json, {:group => :integration, :expire => expire_time || 300}).set_key
  end

end
