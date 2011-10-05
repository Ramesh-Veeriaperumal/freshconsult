class AuthorizationsController < ApplicationController
  before_filter :require_user, :only => [:destroy]
  before_filter :fetch_request_details,:only => :create
  
  def fetch_request_details
    @omniauth = request.env['rack.auth'] 
    @auth = Authorization.find_from_hash(@omniauth,current_account.id)
     if @omniauth['provider'] == 'open_id' 
      requires_feature(:google_signin)
    elsif
      requires_feature(:twitter_signin)
    end
  end
  
  def create
     if @omniauth['provider'] == 'open_id' 
      create_for_google
    elsif
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
