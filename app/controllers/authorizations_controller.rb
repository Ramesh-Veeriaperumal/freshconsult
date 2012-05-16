require 'httparty'
class AuthorizationsController < ApplicationController
  include Integrations::GoogleContactsUtil
  include Integrations::Oauth2Helper
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
    @omniauth_origin = session["omniauth.origin"]
    if @omniauth['provider'] == :open_id
      create_for_google
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
          # Reuse the group id, if the  group with same name already exist.
          @google_groups.each { |g_group|
            @google_account.sync_group_id = g_group.group_id if g_group.name == @google_account.sync_group_name
          }
          render 'integrations/google_accounts/edit'
        end
      end
    elsif @omniauth['provider'] == "twitter"
      create_for_twitter
    elsif @omniauth['provider'] == "salesforce"
      create_for_salesforce(params)
    elsif @omniauth['provider'] == "facebook"
      create_for_facebook
    end
  end


  def create_for_salesforce(params)
      Rails.logger.debug "Account ID from omniauth origin : " + request.env["rack.session"]["omniauth.origin"] unless request.env["rack.session"]["omniauth.origin"].blank?
      account_id = request.env["rack.session"]["omniauth.origin"] unless request.env["rack.session"]["omniauth.origin"].blank?
      access_token = get_oauth2_access_token(@omniauth.credentials.refresh_token);
      account = Account.find(:first, :conditions => {:id => account_id})
      domain = account.full_domain
      protocol = (account.ssl_enabled?) ? "https://" : "http://"
      application = Integrations::Application.find(:first, :conditions => {:name => 'salesforce'})
      #install installed_applications

      #installed_application = Integrations::InstalledApplication.new
      #installed_application.application = application
      #installed_application.account = account

      installed_application = Integrations::InstalledApplication.find_by_application_id_and_account_id(application.id, account_id)

      installed_application[:configs]={:inputs => {'refresh_token' => @omniauth.credentials.refresh_token, 'oauth_token' => access_token.token, 'instance_url' => access_token.params['instance_url']}}
      installed_application.save!

      #redirect_url = protocol +  domain + ".freshdesk.com" + "/integrations/applications"
      #redirect_url = "https://aravind123.freshdesk.com/integrations/applications"
      #redirect_to redirect_url
      redirect_to show_integrations_application_path(application)
      #render :text => "Test "
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
  
  def create_for_twitter
   @current_user = current_account.all_users.find_by_twitter_id(@omniauth['info']['nickname'])  unless  current_account.blank?
   if !@current_user.blank? and !@auth.blank?
      return show_deleted_message if @current_user.deleted?
      make_usr_active
    elsif !@current_user.blank?
      @current_user.authorizations.create(:provider => @omniauth['provider'], 
      :uid => @omniauth['uid'], :account_id => current_account.id)
      make_usr_active
    else
      flash[:notice] = t('twitter.usr_not_thr')
      return redirect_to login_url
    end  
    create_session
  end
  
  def show_deleted_message
    flash[:notice] = t(:'flash.g_app.user_deleted')
    redirect_to login_url
  end
  
  def make_usr_active
     @current_user.active = true 
     @current_user.save!
  end
  
  def create_for_google
    @current_user = current_account.all_users.find_by_email(@omniauth['info']['email'])  unless  current_account.blank?
    if !@current_user.blank? and !@auth.blank?
      puts "Current user not blank"
      return show_deleted_message if @current_user.deleted?
      make_usr_active
    elsif !@current_user.blank?
      puts "current user is black"
      @current_user.authorizations.create(:provider => @omniauth['provider'], :uid => @omniauth['uid'], :account_id => current_account.id) #Add an auth to existing user
      make_usr_active
    else  
      @new_auth = create_from_hash(@omniauth) 
      @current_user = @new_auth.user
    end
    create_session
  end

  def create_for_facebook
    @current_user = current_account.all_users.find_by_fb_profile_id(@omniauth['info']['nickname'])  unless  current_account.blank?
    if !@current_user.blank? and !@auth.blank?
      return show_deleted_message if @current_user.deleted?
      make_usr_active
    elsif !@current_user.blank?
      @current_user.authorizations.create(:provider => @omniauth['provider'], :uid => @omniauth['uid'], :account_id => current_account.id) #Add an auth to existing user
      make_usr_active
    else  
      @new_auth = create_from_hash(@omniauth) 
      @current_user = @new_auth.user
    end
    create_session
  end
  
  def create_from_hash(hash)
    user = current_account.users.new
    user.name =  hash['info']['name']
    user.email =  hash['info']['email']
    user.fb_profile_id = hash['info']['nickname'] if @omniauth['provider'] == "facebook"
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
