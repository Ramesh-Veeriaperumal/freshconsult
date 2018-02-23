# encoding: utf-8
require 'httparty'
require 'cgi'
require 'json'

class AuthorizationsController < ApplicationController
  include Integrations::OauthHelper
  include Integrations::Constants
  include HTTParty
  include Helpdesk::Permission::User

  skip_before_filter :check_privilege, :verify_authenticity_token
  skip_before_filter :set_current_account, :redactor_form_builder, :check_account_state, :set_time_zone,
                    :check_day_pass_usage, :set_locale, :only => [:create, :failure]
  before_filter :require_user, :only => [:destroy]
  before_filter :load_authorization, :only => [:create]
  skip_after_filter :set_last_active_time

  def create
    Rails.logger.debug "@omniauth "+@omniauth.inspect
    failure if @omniauth.blank?
    @omniauth_origin = session["omniauth.origin"]
    if @omniauth['provider'] == APP_NAMES[:twitter]
      twitter_id = @omniauth['info']['nickname']
      @current_user = current_account.all_users.find_by_twitter_id(twitter_id)  if current_account.present?
      create_for_sso(@omniauth)
    elsif OAUTH2_PROVIDERS.include?(@omniauth['provider'])
      create_for_oauth2(@omniauth['provider'], params)
    elsif EMAIL_MARKETING_PROVIDERS.include?(@omniauth['provider'])
      create_for_email_marketing_oauth(@omniauth['provider'], params)
    elsif OAUTH1_PROVIDERS.include?(@omniauth['provider'])
      create_for_oauth1(@omniauth['provider'], params)
    end
  end

  def select_shard(&block)
    load_origin_info if ['create', 'failure'].include?(params[:action])
    raise ActionController::RoutingError, "Not Found" if @account_id.nil? and origin_required?
    Sharding.select_shard_of(@account_id || request.host) do
      yield
    end
  end

  def load_origin_info
    origin = request.env["omniauth.origin"].present? ? request.env["omniauth.origin"] : params[:origin]
    @omniauth = request.env['omniauth.auth'] 
    @provider = (@omniauth and @omniauth['provider']) ? @omniauth['provider'] : params[:provider]

    raise ActionController::RoutingError, "Not Found" if origin.blank? and origin_required?
    
    if /^\d+$/.match(origin)        # Fallback         
      origin = origin.to_i if origin_required?
      @app_name = Integrations::Constants::PROVIDER_TO_APPNAME_MAP["#{@provider}"] unless @provider.blank?
      portal = Portal.find(origin.to_i)
      @account_id = portal.account_id if portal
    else
      origin = CGI.parse(origin)
      @app_name = origin['app_name'][0].to_s if origin.has_key?('app_name')
      @app_name ||= Integrations::Constants::PROVIDER_TO_APPNAME_MAP["#{@provider}"] unless @provider.blank?
      @origin_user_id = origin.has_key?('user_id') ? origin['user_id'][0].to_i : params[:user_id]
      if origin.has_key?('id') 
        @account_id = origin['id'][0].to_i
        @portal_id = origin['portal_id'][0].to_i if origin.has_key?('portal_id') 
      elsif origin.has_key?('pid') # Fallback
        origin = origin['pid'][0].to_i
        portal = Portal.find(origin.to_i)
        @account_id = portal.account_id if portal
      end
    end
  end

  def load_authorization
    @auth = Authorization.find_from_hash(@omniauth, current_account.id) unless @provider == APP_NAMES[:facebook]
    if (@provider == APP_NAMES[:twitter])
      requires_feature("#{@provider}_signin")
    end
  end

  def origin_required?
    request.host == AppConfig['integrations_url'][Rails.env].gsub(/https?:\/\//i, '') or
     (Rails.env.development? and
      request.host == AppConfig['integrations_url'][Rails.env].gsub(/https?:\/\//i, '').gsub(/:3000/i,''))
  end

  def create_for_oauth1(provider, params)
    config_params = {
      'app_name' => "#{@app_name}",
      'oauth_token' => "#{@omniauth.credentials.token}",
      'oauth_token_secret' => "#{@omniauth.credentials.secret}"
    }

    if (provider == APP_NAMES[:quickbooks])
      config_params['company_id'] = params['realmId']
      config_params['token_renewal_date'] = Time.now + Integrations::Quickbooks::Constant::TOKEN_RENEWAL_DAYS.days
    end
    set_oauth_redirect_url(config_params)
  end

  def create_for_oauth2(provider, params)
    if OAUTH2_OMNIAUTH_CRENDENTIALS.include? provider
      access_token = @omniauth.credentials
    else
      access_token = get_oauth2_access_token(provider, @omniauth.credentials.refresh_token, @app_name)
    end

    config_params = { 
      'app_name' => "#{@app_name}",
      'refresh_token' => "#{@omniauth.credentials.refresh_token}",
      'oauth_token' => "#{access_token.token}"
    }

    case provider
      when APP_NAMES[:box]
        config_params['email'] = @omniauth.extra.raw_info.login
    end

    set_oauth_redirect_url(config_params)
  end

    def create_for_email_marketing_oauth(provider, params)
    config_params = {}
    config_params["mailchimp"] = "{'app_name':'#{provider}', 'api_endpoint':'#{@omniauth.extra.metadata.api_endpoint}', 'oauth_token':'#{@omniauth.credentials.token}'}" if provider == "mailchimp"
    config_params["constantcontact"] = "{'app_name':'#{provider}', 'oauth_token':'#{@omniauth.credentials.token}', 'uid':'#{@omniauth.uid}'}" if provider == "constantcontact"
    config_params = config_params[provider].gsub("'","\"")

    
    #Redis::KeyValueStore is used to store nimble configurations since we redirect from login.freshdesk.com to the 
    #user's account and install the application from inside the user's account.
    key_options = { :account_id => @account_id, :provider => provider}
    key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
    Redis::KeyValueStore.new(key_spec, config_params, {:group => :integration, :expire => 300}).set_key
    app = get_integrated_app
    redirect_url = get_redirect_url(app,provider)
     
    redirect_to redirect_url
  end

  def create_session
    @user_session = @current_user.account.user_sessions.new(@current_user)
    @user_session.web_session = true unless is_native_mobile?
    if @user_session.save
      if grant_day_pass
        cookies["mobile_access_token"] = { :value => @current_user.mobile_auth_token, :http_only => true } if is_native_mobile?
        redirect_back_or_default('/') 
      end
    else
      flash[:notice] = t(:'flash.g_app.authentication_failed')
      redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  def show_deleted_message
    if params[:state]
      render :text => t(:'flash.g_app.page_unavailable')
    else
      flash[:notice] = t(:'flash.g_app.page_unavailable')
      redirect_to login_url
    end
  end
  
  def make_usr_active
     @current_user.active = true 
     @current_user.save!
  end

  def create_for_sso(hash, user_account = nil)
    account = (user_account.blank?) ? current_account : user_account
    account.make_current
    if !@current_user.blank? and !@auth.blank?
      if @current_user.deleted?
        show_deleted_message
        return false
      end
      make_usr_active
    elsif !@current_user.blank?
      @current_user.authorizations.create(:provider => hash['provider'], :uid => hash['uid'], :account_id => account.id) #Add an auth to existing user  
      make_usr_active
    else  
      @new_auth = create_from_hash(hash, account) 
      @current_user = @new_auth.user
    end
    create_session unless @omniauth['provider'] == APP_NAMES[:facebook]
    return true
  end
  
  def create_from_hash(hash, account)
    user = account.users.new  
    user.name = hash['info']['name']
    user.email = hash['info']['email'] if hash['info']['email']
    unless hash['info']['nickname'].blank?
      user.twitter_id = hash['info']['nickname'] if hash['provider'] == APP_NAMES[:twitter]
      user.fb_profile_id = hash['info']['nickname'] if hash['provider'] == APP_NAMES[:facebook]
    end
    user.helpdesk_agent = false
    user.active = true
    user.language = account.language
    user.save!
    user.reset_persistence_token! 
    Authorization.create(:user_id => user.id, :uid => hash['uid'], :provider => hash['provider'],:account_id => account.id)
  end

  def failure
    port = (Rails.env.development? ? ":#{request.port}" : '')
    path = ''
    if @app_name 
      app = Integrations::Application.find_by_name(@app_name)
      path = '/integrations/applications' if (app and !app.options[:user_specific_auth]) 
    end
    flash[:notice] = t(:'flash.g_app.authentication_failed')
    redirect_to portal_url+port+path
  end

  def portal_url account=nil
    account ||= Account.find(@account_id || DomainMapping.find_by_domain(request.host).account_id)
    portal = (@portal_id ? Portal.find(@portal_id) : account.main_portal)
    protocol  = portal.ssl_enabled? ? 'https://' : 'http://'
    port = ''
    @portal_url = protocol + portal.host + port
  end

  def get_integrated_app
    @application ||= Integrations::Application.find_by_name(@app_name)
  end

  def destroy
    @authorization = current_user.authorizations.find(params[:id])
    @authorization.destroy
    redirect_to root_url
  end

  def get_redirect_url(app,name)
    path = portal_url
    if app.user_specific_auth?
      path += '/support' if origin_user.customer?
      path += "/integrations/user_credentials/oauth_install/#{name}"
    else
      path += "/integrations/applications/oauth_install/#{name}"
    end
    path
  end

  def origin_account
    @origin_account ||= @account_id ? Account.find_by_id(@account_id) : current_account
  end

  def origin_user
    @origin_user ||= 
      origin_account.all_users.find_by_id(@origin_user_id) if origin_account && @origin_user_id
  end

  private
    def set_oauth_redirect_url(config_params)
      config_params = config_params.to_json
      app = get_integrated_app
      #Redis::KeyValueStore is used to store oauth2 configurations since we redirect from login.freshdesk.com to the
      #user's account and install the application from inside the user's account.
      key_options = { :account_id => @account_id, :provider => @app_name}
      key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
      Redis::KeyValueStore.new(key_spec, config_params, {:group => :integration, :expire => 300}).set_key

      redirect_url = get_redirect_url(app,@app_name)
      redirect_to redirect_url
    end

  OAUTH1_PROVIDERS = ["quickbooks"]
  OAUTH2_PROVIDERS = ["nimble", "surveymonkey", "box"]
  EMAIL_MARKETING_PROVIDERS = ["mailchimp", "constantcontact"]
  OAUTH2_OMNIAUTH_CRENDENTIALS = ["surveymonkey"]
end
