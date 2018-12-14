class Auth::SalesforceV2Authenticator < Auth::Authenticator

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
    omniauth.provider(
      :salesforce,
      Integrations::OAUTH_CONFIG_HASH["salesforce_v2"]["consumer_token"],
      Integrations::OAUTH_CONFIG_HASH["salesforce_v2"]["consumer_secret"],
      :name         => "salesforce_v2")
  end

  def get_redirect_url
    (@falcon_enabled == 'true') ? "#{@portal_url}/" + "a/admin/" + "#{sf_sync_url}" :
                                  "#{@portal_url}/" + "#{sf_sync_url}"
  end

  def sf_sync_url
    "integrations/sync/crm/instances?state=salesforce_v2&method=post"
  end
end