class Auth::GmailAuthenticator < Auth::Authenticator
  include Email::Mailbox::Utils
  include Email::Mailbox::Errors
  GMAIL_OAUTH_KEYS = %w[refresh_token oauth_token]
  LANDING_PATH = '/a/admin/email/mailboxes'.freeze

  def after_authenticate(params)
    if @failed
      @result.failed = @failed
      @result.failed_reason = @failed_reason
      raise Email::Mailbox::Errors::GoogleAuthenticateFailure.new("#{@result.failed_reason} failure in Google Authentication.")
    elsif @options[:r_key].present?
      gmail_redis_params = process_gmail_oauth(build_config_params)
      @result.redirect_url = get_redirect_url(build_URL(gmail_redis_params) + "&oauth_status=success", gmail_redis_params)
    else
      raise Email::Mailbox::Errors::MissingRedis.new('missing redis key in google callback')
    end
    @result
  rescue Email::Mailbox::Errors::MissingRedis => e
    Rails.logger.error "GmailAuthenticator - #{e.message}"
    @result.redirect_url = get_redirect_url(e.url_params_string + "&oauth_status=failure", gmail_oauth_redis_obj(@options[:r_key]).fetch_hash)
    @result
  rescue Email::Mailbox::Errors::GoogleAuthenticateFailure => e
    Rails.logger.info "GmailAuthenticator - #{e.message}"
    gmail_redis_params = gmail_oauth_redis_obj(@options[:r_key]).fetch_hash
    url_string = build_URL(gmail_redis_params) + "&#{e.url_params_string}&oauth_status=failure"
    @result.redirect_url = get_redirect_url(url_string, gmail_redis_params)
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

    # this is the final redirection to ember.
    def get_redirect_url(url_params_string, gmail_redis_params)
      protocol = Rails.env.development? ? 'http' : 'https'
      port = Rails.env.development? ? ':4200' : ''
      if gmail_redis_params['type'] == 'new'
        landing_path = LANDING_PATH + '/new'
      else
        landing_path = LANDING_PATH + "/#{gmail_redis_params['id']}/edit"
      end
      redirect_domain = "#{protocol}://#{@origin_account.full_domain}#{port}#{landing_path}?#{url_params_string}"
    end
    
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
      save_email_config(gmail_redis_params) #TODO remove method after api stories are done.
      gmail_redis_params
    end

    def set_redis_keys(oauth_redis_key, gmail_oauth_hash)
      gmail_oauth_redis_obj(oauth_redis_key).populate_hash(gmail_oauth_hash)
    end

    def gmail_oauth_redis_obj(oauth_redis_key)
      @gmail_oauth_redis_obj ||= Email::Mailbox::GmailOauthRedis.new({redis_key: oauth_redis_key})
    end
    
    def save_email_config(model_params) # Temp method for testing purpose before apis are implemented
      @origin_account.make_current
      email_config_params = model_params.clone

      if email_config_params['type'] == 'new'
        email_config_params[:reply_email] = email_config_params.delete('support_email')
        email_config_params[:to_email] = construct_to_email(email_config_params[:reply_email], @origin_account.full_domain)
        
        email_config_params[:imap_mailbox_attributes] = {
          user_name: email_config_params['oauth_email'],
          password: email_config_params['oauth_token'],
          refresh_token: email_config_params['refresh_token'],
          authentication: 'xoauth2',
          server_name: 'imap.gmail.com',
          port: 993,
          delete_from_server: false,
          use_ssl: 1
        }
        email_config_params[:smtp_mailbox_attributes] = {
          user_name: email_config_params.delete('oauth_email'),
          password: email_config_params.delete('oauth_token'),
          refresh_token: email_config_params.delete('refresh_token'),
          authentication: 'xoauth2',
          server_name: 'smtp.gmail.com',
          port: 587,
          use_ssl: 1
        }
        
        email_config_params.delete('type')
        item = @origin_account.email_configs.new(email_config_params)
        item.save
        Rails.logger.info "email config created with oauth #{item.id}"
      else
        item = @origin_account.all_email_configs.find_by_id(email_config_params['id'])

        email_config_params[:reply_email] = email_config_params.delete('support_email') if email_config_params['support_email'].present?
        email_config_params[:to_email] = construct_to_email(email_config_params[:reply_email], @origin_account.full_domain) if email_config_params[:reply_email].present?

        email_config_params[:imap_mailbox_attributes] = {
          user_name: email_config_params['oauth_email'],
          password: email_config_params['oauth_token'],
          refresh_token: email_config_params['refresh_token'],
          id: item.imap_mailbox.id
        }
        email_config_params[:smtp_mailbox_attributes] = {
          user_name: email_config_params.delete('oauth_email'),
          password: email_config_params.delete('oauth_token'),
          refresh_token: email_config_params.delete('refresh_token'),
          id: item.smtp_mailbox.id
        }
        
        email_config_params.delete('type')
        email_config_params.delete('id')
        item.update_attributes(email_config_params)
        item.save
        Rails.logger.info "email config edited with oauth #{item.id}"
      end
    end
    
    def build_URL(params)
      url_params_arr = ["ref_key=#{@options[:r_key]}"]    
      params.except(*GMAIL_OAUTH_KEYS).each_pair { |name, val| url_params_arr << "#{name}=#{val}" }
      url_params_arr.join('&')
    end
end
