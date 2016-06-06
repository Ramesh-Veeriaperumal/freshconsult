class Auth::SalesforceSyncAuthenticator < Auth::Authenticator

  def after_authenticate(params)
    access_token = @omniauth.credentials
    config_params = {
      'app_name' => "#{@app.name}",
      'oauth_token' => "#{access_token.token}",
      'instance_url' => "#{access_token.instance_url}",
      'refresh_token' => "#{access_token.refresh_token}"
    }
    set_redis_keys config_params, 3600
    @result.redirect_url = get_redirect_url
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider :salesforce_sync,
                      :setup => lambda { |env|
      strategy = env["omniauth.strategy"]
      strategy.options[:client_id] = Integrations::OAUTH_CONFIG_HASH["salesforce_sync"]["consumer_token"]
      strategy.options[:client_secret] = Integrations::OAUTH_CONFIG_HASH["salesforce_sync"]["consumer_secret"]
    }
  end

  def get_redirect_url
    "#{@portal_url}/integrations/sync/crm/instances?state=sfdc"
  end
end