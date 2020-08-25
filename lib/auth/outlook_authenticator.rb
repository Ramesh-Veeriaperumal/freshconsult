# frozen_string_literal: true

class Auth::OutlookAuthenticator < Auth::Authenticator
  include Email::Mailbox::Utils
  include Email::Mailbox::Errors
  include Email::Mailbox::OauthAuthenticatorHelper
  LANDING_PATH = '/a/admin/email/mailboxes'

  def after_authenticate(_params)
    if @failed
      @result.failed = @failed
      @result.failed_reason = @failed_reason
      raise Email::Mailbox::Errors::Oauth2AuthenticateFailure, "#{@result.failed_reason} failure in Microsoft Authentication."
    elsif @options[:r_key].present?
      redis_params = process_oauth(build_config_params)
      @result.redirect_url = get_redirect_url(build_url(redis_params, OAUTH_SUCCESS, @options[:r_key]) + "&oauth_status=#{OAUTH_SUCCESS}", redis_params, @origin_account)
    else
      raise Email::Mailbox::Errors::MissingRedis, 'missing redis key in microsoft callback'
    end
    @result
  rescue Email::Mailbox::Errors::MissingRedis => e
    Rails.logger.error "OutlookAuthenticator - #{e.message}"
    @result.redirect_url = get_redirect_url(e.url_params_string + "&oauth_status=#{OAUTH_FAILED}", oauth_redis_obj(@options[:r_key]).fetch_hash, @origin_account)
    @result
  rescue Email::Mailbox::Errors::Oauth2AuthenticateFailure => e
    Rails.logger.info "OutlookAuthenticator - #{e.message}"
    redis_params = oauth_redis_obj(@options[:r_key]).fetch_hash
    url_string = build_url(redis_params, OAUTH_FAILED, @options[:r_key]) + "&#{e.url_params_string}&oauth_status=#{OAUTH_FAILED}"
    @result.redirect_url = get_redirect_url(url_string, redis_params, @origin_account)
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider(
      :outlook,
      Integrations::OAUTH_CONFIG_HASH['outlook']['consumer_token'],
      Integrations::OAUTH_CONFIG_HASH['outlook']['consumer_secret'],
      scope: 'openid email profile offline_access https://outlook.office.com/IMAP.AccessAsUser.All https://outlook.office.com/SMTP.Send User.Read',
      redirect_uri: "#{AppConfig['integrations_url'][Rails.env]}/auth/outlook/callback",
      name: 'outlook'
    )
  end

  private

    def build_config_params
      {
        'refresh_token' => @omniauth.credentials.refresh_token.to_s,
        'oauth_token' => @omniauth.credentials.token.to_s,
        'oauth_email' => (@omniauth['extra']['raw_info']['EmailAddress']).to_s
      }
    end

    def process_oauth(config_params)
      set_redis_keys(@options[:r_key], config_params)
      redis_params = oauth_redis_obj(@options[:r_key]).fetch_hash
      Rails.logger.info "outlook redis members #{redis_params.inspect}"
      redis_params
    end

    def set_redis_keys(oauth_redis_key, oauth_hash)
      oauth_redis_obj(oauth_redis_key).populate_hash(oauth_hash)
    end

    def oauth_redis_obj(oauth_redis_key)
      @oauth_redis_obj ||= Email::Mailbox::OauthRedis.new(redis_key: oauth_redis_key)
    end
end
