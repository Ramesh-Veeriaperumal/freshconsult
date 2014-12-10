# encoding: utf-8
require 'httparty'
require 'cgi'
require 'json'

class AuthorizationsController < ApplicationController
  include Integrations::GoogleContactsUtil
  include Integrations::OauthHelper
  include HTTParty

  skip_before_filter :check_privilege, :verify_authenticity_token
  skip_before_filter :set_current_account, :redactor_form_builder, :check_account_state, :set_time_zone,
                    :check_day_pass_usage, :set_locale, :only => [:create, :failure]
  before_filter :require_user, :only => [:destroy]
  before_filter :load_authorization, :only => [:create]

  def create
    Rails.logger.debug "@omniauth "+@omniauth.inspect
    failure if @omniauth.blank?
    @omniauth_origin = session["omniauth.origin"]
    if @omniauth['provider'] == :open_id #possible dead code
      current_account.make_current
      @current_user = current_account.user_emails.user_for_email(@omniauth['info']['email'])  unless  current_account.blank?
      create_for_sso(@omniauth)
    elsif @omniauth['provider'] == "twitter"
      twitter_id = @omniauth['info']['nickname']
      @current_user = current_account.all_users.find_by_twitter_id(twitter_id)  unless  current_account.blank?
      create_for_sso(@omniauth)
    elsif @omniauth['provider'] == "facebook"
      create_for_facebook(params)
    elsif @omniauth['provider'] == "google"
      create_for_google(params)
    elsif OAUTH2_PROVIDERS.include?(@omniauth['provider'])
      create_for_oauth2(@omniauth['provider'], params)
    elsif EMAIL_MARKETING_PROVIDERS.include?(@omniauth['provider'])
      create_for_email_marketing_oauth(@omniauth['provider'], params)
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
      @app_name = Integrations::Constants::APP_NAMES[@provider.to_sym] unless @provider.blank?
      portal = Portal.find(origin.to_i)
      @account_id = portal.account_id if portal
    else
      origin = CGI.parse(origin)
      @app_name = origin['app_name'][0].to_s if origin.has_key?('app_name')
      @app_name ||= Integrations::Constants::APP_NAMES[@provider.to_sym] unless @provider.blank?
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
    @auth = Authorization.find_from_hash(@omniauth,current_account.id) unless @provider == "facebook"
    if (@provider == :open_id or @provider == :twitter or @provider == :facebook)
      @provider = (@provider == :open_id ? :google : @provider)
      requires_feature("#{@provider}_signin")
    end
  end

  def origin_required?
    request.host == AppConfig['integrations_url'][Rails.env].gsub(/https?:\/\//i, '') or
     (Rails.env.development? and
      request.host == AppConfig['integrations_url'][Rails.env].gsub(/https?:\/\//i, '').gsub(/:3000/i,''))
  end

  def create_for_google(params)
    user_info = @omniauth['info']
    unless user_info.blank?
      if @omniauth_origin.blank? || @omniauth_origin.include?("integrations") 
        Rails.logger.error "The session variable to omniauth is not preserved or not set properly."
        @omniauth_origin = "install"
      end
      @google_account = Integrations::GoogleAccount.new
      @db_google_account = Integrations::GoogleAccount.find_by_account_id_and_email(current_account, user_info["email"])
      if !@db_google_account.blank? && @omniauth_origin == "install"
        Rails.logger.error "As already an account has been configured can not configure one more account."
        flash[:error] = t("integrations.google_contacts.already_exist")
        redirect_to edit_integrations_installed_application_path(params[:iapp_id]) 
      else
        @existing_google_accounts = Integrations::GoogleAccount.find_all_by_account_id(current_account)
        @google_account.account = current_account
        @google_account.token = @omniauth['credentials']['token']
        @google_account.secret = @omniauth['credentials']['secret']
        @google_account.name = user_info["name"]
        @google_account.email = user_info["email"]
        @google_account.sync_group_name = "Freshdesk Contacts"
        Rails.logger.debug "@google_account details #{@google_account.inspect} existing_google_accounts #{@existing_google_accounts.inspect}"
        # Fetch all the groups
        @google_groups = @google_account.fetch_all_google_groups
        # Reuse the group id, if the group with same name already exist.
        @google_groups.each { |g_group|
          @google_account.sync_group_id = g_group.group_id if g_group.name == @google_account.sync_group_name
        }
        render 'integrations/google_accounts/edit'
      end
    end
  end

  def create_for_oauth2(provider, params)

    if provider  == 'surveymonkey' || provider == "shopify"
      access_token = @omniauth.credentials
    else
      access_token = get_oauth2_access_token(provider, @omniauth.credentials.refresh_token, @app_name)
    end
    
    config_params = { 
      'app_name' => "#{@app_name}",
      'refresh_token' => "#{@omniauth.credentials.refresh_token}",
      'oauth_token' => "#{access_token.token}"
    }

    config_params['instance_url'] = "#{access_token.params['instance_url']}" if provider=='salesforce'
    config_params['shop_name'] = params[:shop] if provider == "shopify"
    config_params = config_params.to_json

    #Redis::KeyValueStore is used to store oauth2 configurations since we redirect from login.freshdesk.com to the
    #user's account and install the application from inside the user's account.
    key_options = { :account_id => @account_id, :provider => @app_name}
    key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
    Redis::KeyValueStore.new(key_spec, config_params, {:group => :integration, :expire => 300}).set_key
    port = (Rails.env.development? ? ":#{request.port}" : '')
    controller = ( Integrations::Application.find_by_name(@app_name).user_specific_auth? ? 'integrations/user_credentials' : 'integrations/applications' )
    redirect_url = portal_url + port + "/#{controller}/oauth_install/#{@app_name}"
    redirect_to redirect_url
  end

    def create_for_email_marketing_oauth(provider, params)
    config_params = {}
    
    config_params["mailchimp"] = "{'app_name':'#{provider}', 'api_endpoint':'#{@omniauth.extra.metadata.api_endpoint}', 'oauth_token':'#{@omniauth.credentials.token}'}" if provider == "mailchimp"
    config_params["constantcontact"] = "{'app_name':'#{provider}', 'oauth_token':'#{@omniauth.credentials.token}', 'uid':'#{@omniauth.uid}'}" if provider == "constantcontact"
    config_params = config_params[provider].gsub("'","\"")

    #Redis::KeyValueStore is used to store salesforce/nimble configurations since we redirect from login.freshdesk.com to the 
    #user's account and install the application from inside the user's account.
    key_options = { :account_id => @account_id, :provider => provider}
    key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
    Redis::KeyValueStore.new(key_spec, config_params, {:group => :integration, :expire => 300}).set_key
    port = (Rails.env.development? ? ":#{request.port}" : '')
    redirect_url = portal_url + port + "/integrations/applications/oauth_install/"+provider
     
    redirect_to redirect_url
  end

  def create_for_facebook(params)
    state = "/facebook" if params[:state]
    user_account = Account.find @account_id
    user_account.make_current
    fb_email = @omniauth['info']['email']
    unless user_account.blank?
      @current_user = user_account.user_emails.user_for_email(fb_email) unless fb_email.blank?
      @auth = Authorization.find_from_hash(@omniauth,user_account.id)
      fb_profile_id = @omniauth['info']['nickname']
      @current_user = user_account.all_users.find_by_fb_profile_id(fb_profile_id) if @current_user.blank? and !fb_profile_id.blank?
      if create_for_sso(@omniauth, user_account)
        curr_time = ((DateTime.now.to_f * 1000).to_i).to_s
        random_hash = Digest::MD5.hexdigest(curr_time)
        key_options = { :account_id => user_account.id, :user_id => @current_user.id, :provider => @omniauth['provider']}
        key_spec = Redis::KeySpec.new(Redis::RedisKeys::SSO_AUTH_REDIRECT_OAUTH, key_options)
        Redis::KeyValueStore.new(key_spec, curr_time, {:group => :integration, :expire => 300}).set_key
        port = (Rails.env.development? ? ":#{request.port}" : '')
        fb_url = (params[:state] ? "#{user_account.main_url_protocol}://#{user_account.full_domain}" : portal_url(user_account))
        redirect_to fb_url + "#{port}#{state}/sso/login?provider=facebook&uid=#{@omniauth['uid']}&s=#{random_hash}" 
      end
    end
  end

  def create_session
    @user_session = @current_user.account.user_sessions.new(@current_user)
    if @user_session.save
      if grant_day_pass
        cookies["mobile_access_token"] = { :value => @current_user.single_access_token, :http_only => true } if is_native_mobile?
        redirect_back_or_default('/') 
      end
    else
      flash[:notice] = t(:'flash.g_app.authentication_failed')
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
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
    create_session unless @omniauth['provider'] == "facebook"
    return true
  end
  
  def create_from_hash(hash, account)
    user = account.users.new  
    user.name = hash['info']['name']
    user.email = hash['info']['email'] if hash['info']['email']
    unless hash['info']['nickname'].blank?
      user.twitter_id = hash['info']['nickname'] if hash['provider'] == 'twitter'
      user.fb_profile_id = hash['info']['nickname'] if hash['provider'] == 'facebook'
    end
    user.helpdesk_agent = false
    user.active = true
    user.language = account.language
    user.save 
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
      return (protocol + portal.host)
  end
  
  def destroy
    @authorization = current_user.authorizations.find(params[:id])
    @authorization.destroy
    redirect_to root_url
  end

  OAUTH2_PROVIDERS = ["salesforce", "nimble", "google_oauth2", "surveymonkey", "shopify"]
  EMAIL_MARKETING_PROVIDERS = ["mailchimp", "constantcontact"]
end
