class Auth::GoogleMarketplaceSsoAuthenticator < Auth::Authenticator
  include Integrations::GoogleAppsHelper

  def after_authenticate(params)
    return non_hd_account if google_domain.blank?
    account_id = account_from_google_domain
    if account_id.blank?
      onboard
    else
      Sharding.select_shard_of(account_id) do
        sso(account_id, params)
      end
    end
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider(
      :google_oauth2,
      Integrations::OAUTH_CONFIG_HASH["google_oauth2"]["consumer_token"],
      Integrations::OAUTH_CONFIG_HASH["google_oauth2"]["consumer_secret"],
      :scope        => "https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email",
      :prompt       => "select_account consent",
      :access_type  => "online",
      :state        => "ignore_build%3Dtrue",
      :redirect_uri => "#{AppConfig['integrations_url'][Rails.env]}/auth/google_marketplace_sso/callback",
      :name         => "google_marketplace_sso")
  end

end
