class AuthorizationsController < ApplicationController
  include Integrations::GoogleContactsUtil

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
    puts "@omniauth "+@omniauth.inspect
    @omniauth_origin = session["omniauth.origin"]
    if @omniauth['provider'] == 'open_id'
      create_for_google
    elsif @omniauth['provider'] == 'google'
      # Move this to GoogleAccount model.
      user_info = @omniauth['user_info']
      unless user_info.blank?
        if @omniauth_origin.blank? || @omniauth_origin.include?("integrations") 
          Rails.logger.error "The session variable to omniauth is not preserved or not set properly."
          @omniauth_origin = "install"
        end
        @google_account = Integrations::GoogleAccount.new
        @db_google_account = Integrations::GoogleAccount.find_by_account_id(current_account)
        if !@db_google_account.blank? && @omniauth_origin == "install"
          puts "As already an account has been configured can not configure one more account."
          flash[:error] = t("integrations.google_contacts.already_exist")
          redirect_to configure_integrations_installed_application_path(params[:iapp_id]) 
        else
          @google_account.account = current_account
          @google_account.token = @omniauth['credentials']['token']
          @google_account.secret = @omniauth['credentials']['secret']
          @google_account.name = user_info["name"]
          @google_account.email = user_info["email"]
          puts "@google_account details #{@google_account.inspect} @db_google_account #{@db_google_account.inspect}"
#          begin
#            @google_account = @google_account.save!
#          rescue Exception => msg
#            puts "Something went wrong during google account creation (#{msg})"
#            flash[:error] = "Error during google signup process."
#          end
          # Fetch only the groups
          @google_groups = @google_account.fetch_all_google_groups
          render 'integrations/google_accounts/edit'
        end
      end
    else
      create_for_twitter
    end
  end

  def create_session
    @user_session = @current_user.account.user_sessions.new(@current_user)
    if @user_session.save
      redirect_back_or_default('/')
    else
      flash[:notice] = t(:'flash.g_app.authentication_failed')
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end
  
  def create_for_twitter
   @current_user = current_account.all_users.find_by_twitter_id(@omniauth['user_info']['nickname'])  unless  current_account.blank?
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
    @current_user = current_account.all_users.find_by_email(@omniauth['user_info']['email'])  unless  current_account.blank?
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
    user.name =  hash['user_info']['name']
    user.email =  hash['user_info']['email']
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
