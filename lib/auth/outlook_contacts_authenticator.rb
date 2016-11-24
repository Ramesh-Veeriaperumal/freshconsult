class Auth::OutlookContactsAuthenticator < Auth::Authenticator

  APP_NAME = Integrations::Constants::APP_NAMES[:outlook_contacts]

  def self.title
    APP_NAME
  end

  def after_authenticate(params)
    access_token = @omniauth.credentials
    config_params = {
      'oauth_token' => "#{access_token.token}",
      'refresh_token' => "#{access_token.refresh_token}",
      'unique_name' => @omniauth.info.email,
      'name' => @omniauth.info.display_name,
      'fd_folder_name' => "Freshdesk Contacts"
    }

    set_redis_keys config_params, 300
    @result.redirect_url = get_redirect_url
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider :outlook_contacts,
      Integrations::OAUTH_CONFIG_HASH[APP_NAME]["consumer_token"],
      Integrations::OAUTH_CONFIG_HASH[APP_NAME]["consumer_secret"]
  end

  def get_redirect_url
    "#{@portal_url}/integrations/outlook_contacts/settings"
  end

end
