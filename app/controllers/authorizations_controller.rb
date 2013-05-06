require 'httparty'
require 'cgi'
require 'json'

class AuthorizationsController < ApplicationController
  include Integrations::GoogleContactsUtil
  include Integrations::OauthHelper
  include HTTParty

  skip_before_filter :check_privilege
  before_filter :require_user, :only => [:destroy]
  before_filter :fetch_request_details,:only => :create

  def fetch_request_details
    @omniauth = request.env['omniauth.auth'] 
    @auth = Authorization.find_from_hash(@omniauth,current_account.id) unless @omniauth['provider'] == "facebook"
    provider_name = @omniauth['provider']

    if provider_name == :open_id or provider_name == :twitter or provider_name == :facebook
      provider_name = provider_name == :open_id ? :google : provider_name
      requires_feature("#{provider_name}_signin")
    end
  end

  def create
    Rails.logger.debug "@omniauth "+@omniauth.inspect
    @omniauth_origin = session["omniauth.origin"]
    if @omniauth['provider'] == :open_id
      @current_user = current_account.all_users.find_by_email(@omniauth['info']['email'])  unless  current_account.blank?
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
    Account.reset_current_account
    origin = request.env["omniauth.origin"] unless request.env["omniauth.origin"].blank?
    if provider == 'google_oauth2'
      origin = CGI.parse(origin)
      portal_id = origin['pid'][0].to_i
      app_name = origin['app_name'][0].to_s
      Rails.logger.debug "origin: #{origin.inspect}"
    else
      portal_id = origin
      app_name = Integrations::Constants::APP_NAMES[provider.to_sym]
    end

    access_token = get_oauth2_access_token(provider, @omniauth.credentials.refresh_token, app_name)

    portal = Portal.find_by_id(portal_id)
    account = portal.account
    domain = portal.host
    protocol = (account.ssl_enabled?) ? "https://" : "http://"

    config_params = { 
      'app_name' => "#{app_name}",
      'refresh_token' => "#{@omniauth.credentials.refresh_token}",
      'oauth_token' => "#{access_token.token}"
    }
    config_params['instance_url'] = "#{access_token.params['instance_url']}" if provider=='salesforce'
    config_params = config_params.to_json
    Rails.logger.debug "config_params: #{config_params}"
    #Redis::KeyValueStore is used to store oauth2 configurations since we redirect from login.freshdesk.com to the
    #user's account and install the application from inside the user's account.
    key_options = { :account_id => account.id, :provider => app_name}
    key_spec = Redis::KeySpec.new(RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
    Redis::KeyValueStore.new(key_spec, config_params, 300).save
    port = (Rails.env.development? ? ":#{request.port}" : '')
    controller = ( Integrations::Application.find_by_name(app_name).user_specific_auth? ? 'integrations/user_credentials' : 'integrations/applications' )
    redirect_url = protocol +  domain + port + "/#{controller}/oauth_install/#{app_name}"
    redirect_to redirect_url
  end
 
    def create_for_email_marketing_oauth(provider, params)
    config_params = {}
    Account.reset_current_account
    portal_id = request.env["omniauth.origin"] unless request.env["omniauth.origin"].blank?
    portal = Portal.find_by_id(portal_id)
    account = portal.account
    domain = portal.host
    protocol = (account.ssl_enabled?) ? "https://" : "http://"
    config_params["mailchimp"] = "{'app_name':'#{provider}', 'api_endpoint':'#{@omniauth.extra.metadata.api_endpoint}', 'oauth_token':'#{@omniauth.credentials.token}'}" if provider == "mailchimp"
    config_params["constantcontact"] = "{'app_name':'#{provider}', 'oauth_token':'#{@omniauth.credentials.token}', 'uid':'#{@omniauth.uid}'}" if provider == "constantcontact"
    config_params = config_params[provider].gsub("'","\"")

    #Redis::KeyValueStore is used to store salesforce/nimble configurations since we redirect from login.freshdesk.com to the 
    #user's account and install the application from inside the user's account.
    key_options = { :account_id => account.id, :provider => provider}
    key_spec = Redis::KeySpec.new(RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
    Redis::KeyValueStore.new(key_spec, config_params, 300).save
    redirect_url = protocol +  domain + "/integrations/applications/oauth_install/"+provider
     
    redirect_to redirect_url
  end

  def create_for_facebook(params)
    Account.reset_current_account
    portal_id = request.env["omniauth.origin"] unless request.env["omniauth.origin"].blank?
    portal = Portal.find_by_id(portal_id)
    user_account = portal.account
    portal_url = portal.host
    protocol = (user_account.ssl_enabled?) ? "https://" : "http://"
    portal_url = protocol + portal_url
    fb_email = @omniauth['info']['email']
    unless user_account.blank?
      @current_user = user_account.all_users.find_by_email(fb_email) unless fb_email.blank?
      @auth = Authorization.find_from_hash(@omniauth,user_account.id)
      fb_profile_id = @omniauth['info']['nickname']
      @current_user = user_account.all_users.find_by_fb_profile_id(fb_profile_id) if @current_user.blank?
      create_for_sso(@omniauth, user_account)
      curr_time = ((DateTime.now.to_f * 1000).to_i).to_s
      random_hash = Digest::MD5.hexdigest(curr_time)
      key_options = { :account_id => user_account.id, :user_id => @current_user.id, :provider => @omniauth['provider']}
      key_spec = Redis::KeySpec.new(RedisKeys::SSO_AUTH_REDIRECT_OAUTH, key_options)
      Redis::KeyValueStore.new(key_spec, curr_time, 300).save
      redirect_to portal_url + "/sso/login?provider=facebook&uid=#{@omniauth['uid']}&s=#{random_hash}" 
    end
  end

  def create_session
    @user_session = @current_user.account.user_sessions.new(@current_user)
    if @user_session.save
        redirect_back_or_default('/') if grant_day_pass
    else
      flash[:notice] = t(:'flash.g_app.authentication_failed')
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  def show_deleted_message
    flash[:notice] = t(:'flash.g_app.user_deleted')
    redirect_to login_url
  end
  
  def make_usr_active
     @current_user.active = true 
     @current_user.save!
  end

  def create_for_sso(hash, user_account = nil)
    account = (user_account.blank?) ? current_account : user_account
    if !@current_user.blank? and !@auth.blank?
      return show_deleted_message if @current_user.deleted?
      make_usr_active
    elsif !@current_user.blank?
      @current_user.authorizations.create(:provider => hash['provider'], :uid => hash['uid'], :account_id => account.id) #Add an auth to existing user  
      make_usr_active
    else  
      @new_auth = create_from_hash(hash, account) 
      @current_user = @new_auth.user
    end
    create_session unless @omniauth['provider'] == "facebook"
  end
  
  def create_from_hash(hash, account)
    user = account.users.new  
    user.name = hash['info']['name']
    user.email = hash['info']['email']
    unless hash['info']['nickname'].blank?
      user.twitter_id = hash['info']['nickname'] if hash['provider'] == 'twitter'
      user.fb_profile_id = hash['info']['nickname'] if hash['provider'] == 'facebook'
    end
    user.helpdesk_agent = false
    user.active = true
    user.save 
    user.reset_persistence_token! 
    Authorization.create(:user_id => user.id, :uid => hash['uid'], :provider => hash['provider'],:account_id => account.id)
  end
  
  def failure
    origin = params[:origin]
    portal = Portal.find_by_id(origin) unless origin.blank?
    unless portal
      origin = CGI.parse(origin) if origin
      portal_id = origin['pid'][0].to_i if origin
      Rails.logger.debug "origin: #{origin.inspect}"  
      portal = Portal.find_by_id(portal_id) if portal_id
    end

    port = (Rails.env.development? ? ":#{request.port}" : '')
    flash[:notice] = t(:'flash.g_app.authentication_failed')
    unless portal.blank?
      domain = portal.host
      protocol = (portal.account.ssl_enabled?) ? "https://" : "http://"
      redirect_to protocol+domain+port
    else
      redirect_to root_url
    end
  end
  
  def destroy
    @authorization = current_user.authorizations.find(params[:id])
    @authorization.destroy
    redirect_to root_url
  end

  OAUTH2_PROVIDERS = ["salesforce", "nimble", "google_oauth2"]
  EMAIL_MARKETING_PROVIDERS = ["mailchimp", "constantcontact"]
end
