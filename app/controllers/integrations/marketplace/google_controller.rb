class Integrations::Marketplace::GoogleController < Integrations::Marketplace::LoginController
  include Redis::RedisKeys
  include Redis::OthersRedis
  skip_before_filter :check_privilege, :verify_authenticity_token, :set_current_account, :check_account_state,
                       :set_time_zone, :check_day_pass_usage, :set_locale, :only => [:onboard, :home, :old_app_redirect]
  
  before_filter :get_redis_keys, :only => [:onboard]

  def old_app_redirect #request comes in from the old app.
    # Refer file -> helpkit/config/google-apps/application-manifest.xml. Navigation url manifest.
    redirect_to "https://" + "#{request.host}" + "/auth/google_marketplace_sso"
  end

  def home
    @rediret_url = "https://www.google.com/a/cpanel/"+ "#{get_google_domain}" 
    render "accounts/thank_you"
  end

  def onboard
    if @domain.present?
      build_onboarding_vars
      render 'integrations/marketplace/associate_account'
    else
      flash.now[:error] = t(:'flash.general.access_denied')
      render 'google_signup/signup_google_error'
    end
  end

  private

    def build_onboarding_vars
      @account = Account.new(:domain => @domain, :name => @name )
      @user = @account.users.new(:email => params["email"], :name => @name)
      @app_name = "google"
      @remote_id = @google_domain
      @operation = "onboarding_google"
      @email_not_reqd = nil
    end

    def get_redis_keys
      redis_oauth_key = GOOGLE_MARKETPLACE_SIGNUP % {:email  => params['email']}
      redis_oauth_value = get_others_redis_key(redis_oauth_key)
      if redis_oauth_value.present?
        key_hash = JSON.parse(redis_oauth_value)
        @uid = key_hash["uid"]
        @name = key_hash["name"]
        @domain = key_hash["domain"]
        @google_domain = key_hash["google_domain"]
        remove_others_redis_key(redis_oauth_key)
      end
    end

    def get_google_domain
      remote_map = Integrations::GoogleRemoteAccount.where(:account_id=> "#{current_account.id}").first
      remote_map.present? ? remote_map.remote_id : nil
    end

    def select_shard(&block)
      yield
    end

end
