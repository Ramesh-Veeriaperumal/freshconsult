require 'httparty'
class AuthorizationsController < ApplicationController
  include Integrations::GoogleContactsUtil
  include Integrations::OauthHelper
  include HTTParty

  before_filter :require_user, :only => [:destroy]
  before_filter :fetch_request_details,:only => :create

  def fetch_request_details
    @omniauth = request.env['omniauth.auth'] 
    @auth = Authorization.find_from_hash(@omniauth,current_account.id)
    provider_name = @omniauth['provider']
    if provider_name == 'open_id' or provider_name == 'google' 
      requires_feature(:google_signin)
    elsif
      requires_feature(:twitter_signin)
    end
  end
  
  def create
    Rails.logger.debug "@omniauth "+@omniauth.inspect
    @omniauth_origin = session["omniauth.origin"]
    if @omniauth['provider'] == :open_id
      puts 'Open ID Provider'
      @current_user = current_account.all_users.find_by_email(@omniauth['info']['email'])  unless  current_account.blank?
      create_for_sso(@omniauth)
    elsif @omniauth['provider'] == "twitter"
      twitter_id = @omniauth['info']['nickname']
      @current_user = current_account.all_users.find_by_twitter_id(twitter_id)  unless  current_account.blank?
      create_for_sso(@omniauth)
    elsif @omniauth['provider'] == "facebook"
      fb_profile_id = @omniauth['info']['nickname']
      @current_user = current_account.all_users.find_by_fb_profile_id(fb_profile_id)  unless  current_account.blank?
      create_for_sso(@omniauth)
    elsif @omniauth['provider'] == "google"
      # Move this to GoogleAccount model.
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
          redirect_to configure_integrations_installed_application_path(params[:iapp_id]) 
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
    elsif @omniauth['provider'] == "salesforce"
      create_for_salesforce(params)
    end
  end

  def create_for_salesforce(params)
    account_id = request.env["rack.session"]["omniauth.origin"] unless request.env["rack.session"]["omniauth.origin"].blank?
    access_token = get_oauth2_access_token(@omniauth.credentials.refresh_token);
    account = Account.find(:first, :conditions => {:id => account_id})
    domain = account.full_domain
    protocol = (account.ssl_enabled?) ? "https://" : "http://"
    app_name = Integrations::Constants::APP_NAMES[:salesforce]
    instance_url = access_token.params['instance_url']
    config_params = "{'app_name':'#{app_name}', 'refresh_token':'#{@omniauth.credentials.refresh_token}', 'oauth_token':'#{access_token.token}', 'instance_url':'#{instance_url}'}"
    config_params = config_params.gsub("'","\"")
    key_value_pair = KeyValuePair.find_by_account_id_and_key(account_id, 'salesforce_oauth_config')
    key_value_pair.delete unless key_value_pair.blank?
    #KeyValuePair is used to store salesforce configurations since we redirect from login.freshdesk.com to the user's account and install the application from inside the user's account.
    create_key_value_pair("salesforce_oauth_config", config_params, account.id) 
    #Integrations::Application.install_or_update(app_name, account.id, config_params)
    redirect_url = protocol +  domain + "/integrations/applications/oauth_install/salesforce"
    #redirect_url = "http://localhost:3000/integrations/applications/oauth_install/salesforce"
    redirect_to redirect_url
  end

  def create_key_value_pair(key, value, account_id)
      app_config = KeyValuePair.new
      app_config.key = key
      app_config.value = value
      app_config.account_id = account_id
      app_config.save!  
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

  def create_for_sso(hash)
    if !@current_user.blank? and !@auth.blank?
      return show_deleted_message if @current_user.deleted?
      make_usr_active
    elsif !@current_user.blank?
      @current_user.authorizations.create(:provider => hash['provider'], :uid => hash['uid'], :account_id => current_account.id) #Add an auth to existing user
      make_usr_active
    else  
      @new_auth = create_from_hash(hash) 
      @current_user = @new_auth.user
    end
    create_session
  end
  
  def create_from_hash(hash)
    user = current_account.users.new
    user.name = hash['info']['name']
    user.email = hash['info']['email']
    unless hash['info']['nickname'].blank?
      user.twitter_id = hash['info']['nickname'] if hash['provider'] == 'twitter'
      user.fb_profile_id = hash['info']['nickname'] if hash['provider'] == 'facebook'
    end
    user.user_role = User::USER_ROLES_KEYS_BY_TOKEN[:customer]
    user.active = true
    user.save 
    user.reset_persistence_token! 
    Authorization.create(:user_id => user.id, :uid => hash['uid'], :provider => hash['provider'],:account_id => current_account.id)
  end
  
  def failure
    flash[:notice] = t(:'flash.g_app.authentication_failed')
    redirect_to root_url
  end
  
  def destroy
    @authorization = current_user.authorizations.find(params[:id])
    @authorization.destroy
    redirect_to root_url
  end
end
