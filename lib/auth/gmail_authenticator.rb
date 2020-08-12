class Auth::GmailAuthenticator < Auth::Authenticator
  include Email::Mailbox::Utils
  include Email::Mailbox::Errors
  include Email::Mailbox::OauthAuthenticatorHelper

  def after_authenticate(_params)
    if @failed
      @result.failed = @failed
      @result.failed_reason = @failed_reason
      raise Email::Mailbox::Errors::AuthenticateFailure, "#{@result.failed_reason} failure in Google Authentication."
    elsif @options[:r_key].present?
      gmail_redis_params = process_gmail_oauth(build_config_params)
      @result.redirect_url = get_redirect_url(build_url(gmail_redis_params, OAUTH_SUCCESS, @options[:r_key]) + "&oauth_status=#{OAUTH_SUCCESS}", gmail_redis_params, @origin_account)
    else
      raise Email::Mailbox::Errors::MissingRedis, 'missing redis key in google callback'
    end
    @result
  rescue Email::Mailbox::Errors::MissingRedis => e
    Rails.logger.error "GmailAuthenticator - #{e.message}"
    @result.redirect_url = get_redirect_url(e.url_params_string + "&oauth_status=#{OAUTH_FAILED}", gmail_oauth_redis_obj(@options[:r_key]).fetch_hash, @origin_account)
    @result
  rescue Email::Mailbox::Errors::AuthenticateFailure => e
    Rails.logger.info "GmailAuthenticator - #{e.message}"
    gmail_redis_params = gmail_oauth_redis_obj(@options[:r_key]).fetch_hash
    url_string = build_url(gmail_redis_params, OAUTH_FAILED, @options[:r_key]) + "&#{e.url_params_string}&oauth_status=#{OAUTH_FAILED}"
    @result.redirect_url = get_redirect_url(url_string, gmail_redis_params, @origin_account)
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider(
      :google_oauth2,
      Integrations::OAUTH_CONFIG_HASH["google_oauth2"]["consumer_token"],
      Integrations::OAUTH_CONFIG_HASH["google_oauth2"]["consumer_secret"],
      :scope        => "https://mail.google.com/ https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email",
      :prompt       => "select_account consent", #we'll get refresh_token only when consent is included!
      :access_type  => "offline",
      :redirect_uri => "#{AppConfig['integrations_url'][Rails.env]}/auth/gmail/callback",
      :name         => "gmail")
  end

  private

    def build_config_params
      {
        'refresh_token' => "#{@omniauth.credentials.refresh_token}",
        'oauth_token'   => "#{@omniauth.credentials.token}",
        'oauth_email'   => "#{@omniauth['info']['email']}"
      }
    end

    def process_gmail_oauth(config_params)
      set_redis_keys(@options[:r_key], config_params)
      gmail_redis_params = gmail_oauth_redis_obj(@options[:r_key]).fetch_hash
      Rails.logger.info "gmail redis members #{gmail_redis_params.inspect}"
      gmail_redis_params
    end

    def set_redis_keys(oauth_redis_key, gmail_oauth_hash)
      gmail_oauth_redis_obj(oauth_redis_key).populate_hash(gmail_oauth_hash)
    end

    def gmail_oauth_redis_obj(oauth_redis_key)
      @gmail_oauth_redis_obj ||= Email::Mailbox::OauthRedis.new(redis_key: oauth_redis_key)
    end

    # Warning:: Deprecated method, should be cleaned up when we launch gmail OAuth for all account.
    def build_URL(params)
      Rails.logger.info("In building gmail oauth url params for account:: #{Account.current.id}, params:: #{params.inspect}")
      url_params_arr = ["reference_key=#{@options[:r_key]}"]
      params.except(*GMAIL_OAUTH_KEYS).each_pair { |name, val| url_params_arr << "#{name}=#{CGI.escape(val)}" }
      url_params_arr.join('&')
    end
end
