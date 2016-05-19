module Integrations::GoogleAppsHelper
    include GoogleLoginHelper

  private

    def onboard
      set_redis_for_onboarding
      @result.redirect_url = "#{AppConfig['integrations_url'][Rails.env]}/integrations/marketplace/google/onboard?email=#{email}"
    end

    def sso account_id
      account = Account.find(account_id)
      account.make_current
      acc_domain = account.full_domain #For the Marketplace-apps-sso always login to account full domain and not portal domain.
      begin
        verify_domain_user(account, false)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
        Rails.logger.debug "Error during Google marketplace association for #{account.id} -> \n #{e.backtrace}"
        @result.flash_message = I18n.t(:'flash.g_app.domain_restriction')
        @result.redirect_url = account.full_url
        return @result
      end
      random_key = SecureRandom.hex
      set_redis_for_sso(random_key)
      @result.redirect_url = redirect_url(account, acc_domain, random_key)
    end

    def non_hd_account
      @result.flash_message  = I18n.t(:'flash.general.access_denied')
      @result.render = { :template => "google_signup/signup_google_error", :layout => "signup_google" }
      @result
    end

    def set_redis_for_onboarding
      config_params = {
        "uid"           => uid,
        "email"         => email,
        "domain"        => google_domain_short,
        "name"          => name,
        "google_domain" => google_domain
      }
      key_options = { :email => email }
      key_spec = Redis::KeySpec.new(Redis::RedisKeys::GOOGLE_MARKETPLACE_SIGNUP, key_options)
      Redis::KeyValueStore.new(key_spec, config_params.to_json, {:group => :integration, :expire => 300}).set_key
    end

    private

      def redirect_url(account, domain_arg, random_key)
        protocol = construct_protocol(account, false)
        protocol + "://" + marketplace_sso_path(domain_arg) + construct_params(domain_arg, random_key)
      end

      def marketplace_sso_path domain_arg
        domain_arg + (Rails.env.development? ? ":3000" : "") + "/sso/marketplace_google_sso"
      end

end