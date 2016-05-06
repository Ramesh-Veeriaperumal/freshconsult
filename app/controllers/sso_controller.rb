class SsoController < ApplicationController

  include Redis::RedisKeys
  include Redis::OthersRedis

  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :check_csrf_token, :only => [:portal_google_sso]
  before_filter :set_current_user, :only =>[:portal_google_sso, :marketplace_google_sso]
  skip_after_filter :set_last_active_time


  def mobile_app_google_login
    redirect_to "https://#{request.host}/auth/google_login"
  end

  def login
    auth = current_account.authorizations.where(:provider => params['provider'], :uid => params['uid']).first
    unless auth.blank?
      curr_user = auth.user
      key_options = { :account_id => current_account.id, :user_id => curr_user.id, :provider => params['provider']}
      kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::SSO_AUTH_REDIRECT_OAUTH, key_options))
      kv_store.group = :integration
      value = kv_store.get_key
      unless value.nil?
        random_hash = Digest::MD5.hexdigest(value)
        expiry = value.to_i + TIMEOUT
        curr_time = (DateTime.now.to_f * 1000).to_i
        if(random_hash == params['s'] and curr_time <= expiry)
          user_session = curr_user.account.user_sessions.new(curr_user)
          kv_store.remove_key
          facebook_redirect = '/facebook/support/home' if params[:portal_type] == 'facebook'
          if user_session.save
            if is_native_mobile?
              cookies["mobile_access_token"] = { :value => curr_user.helpdesk_agent ? curr_user.single_access_token : 'customer', :http_only => true } 
              cookies["fd_mobile_email"] = { :value => curr_user.email, :http_only => true } 
            end
            redirect_back_or_default(facebook_redirect || '/')
          end
          return
        end
      end
      flash[:notice] = t(:'flash.g_app.authentication_failed')
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  def facebook
    redirect_to "#{AppConfig['integrations_url'][Rails.env]}/auth/facebook?origin=id%3D#{current_account.id}%26portal_id%3D#{current_portal.id}&state=#{params[:portal_type]}"
  end

  def portal_google_sso
    protocol = (current_account.ssl_enabled? || is_native_mobile?) ? "https" : "http"
    login_using_google(protocol)
  end

  def marketplace_google_sso
    protocol = current_account.url_protocol
    login_using_google(protocol)
  end

  private

    def set_current_user
      redis_oauth_key = GOOGLE_OAUTH_SSO % {:random_key => params['sso']}
      uid = get_others_redis_key(redis_oauth_key)
      auth = current_account.authorizations.where(:uid => uid, :provider => 'google').first
      user_id = auth.present? ? auth.user_id : nil
      @current_user = user_id.present? ? current_account.users.find_by_id(user_id) : nil
      remove_others_redis_key(redis_oauth_key) if @current_user.present?
    end

    def check_csrf_token
      decoded_token = Base64.decode64(params["at"])
      unless session["_csrf_token"] == decoded_token
        flash[:notice] = t('google_signup.signup_google_error.error_message')
        redirect_to current_account.url_protocol+"://"+portal_url 
      end
    end

    def user_deleted
      flash[:notice] = t('google_signup.signup_google_error.error_message')
      redirect_to login_url
    end

    def login_using_google protocol
      if @current_user.nil? || @current_user.deleted
        user_deleted
      else
        make_user_active
        create_user_session(protocol)
      end
    end

    def create_user_session(protocol)
      @user_session = current_account.user_sessions.new(@current_user)
      if @user_session.save
        return unless grant_day_pass
        if is_native_mobile?
          cookies["mobile_access_token"] = { :value => @current_user.helpdesk_agent ? @current_user.single_access_token : 'customer', :http_only => true } 
          cookies["fd_mobile_email"] = { :value => @current_user.email, :http_only => true } 
        end
        session[:return_to] = protocol+"://"+portal_url + session[:return_to].to_s
        Rails.logger.info "google_login redirect_url #{session[:return_to]}"
        redirect_back_or_default('/')
      else
        redirect_to login_url
      end
    end

    def portal_url
      params['portal_url'].present? ? params['portal_url'] : current_account.host
    end

    def make_user_active
      @current_user.active = true
      @current_user.save
    end

  TIMEOUT = 60000
end
