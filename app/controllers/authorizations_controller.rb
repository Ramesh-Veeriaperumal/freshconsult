class AuthorizationsController < ApplicationController
  before_filter :require_user, :only => [:destroy]

  def create
    omniauth = request.env['rack.auth'] 
    @auth = Authorization.find_from_hash(omniauth,current_account.id)
    @current_user = current_account.all_users.find_by_email(omniauth['user_info']['email'])  unless  current_account.blank?
    if @current_user.deleted?
      flash[:notice] = "User is deleted!"
      redirect_to login_url
      return
    end
    
    if !@current_user.blank? and !@auth.blank?
      @current_user.active = true unless @current_user.active?
    elsif !@current_user.blank?
      @current_user.authorizations.create(:provider => omniauth['provider'], :uid => omniauth['uid'], :account_id => current_account.id) #Add an auth to existing user
    else  
      @new_auth = create_from_hash(omniauth) 
      @current_user = @new_auth.user
    end
    
    @user_session = @current_user.account.user_sessions.new(@current_user)
    if @user_session.save
      redirect_back_or_default('/')
    else
      flash[:notice] = "Authentication Failed"
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end
  
  def create_from_hash(hash)
    user = current_account.users.new
    user.name =  hash['user_info']['name'].scan(/[a-zA-Z0-9_]/).to_s.downcase
    user.email =  hash['user_info']['email']
    if AppConfig['demo_site'][RAILS_ENV] == current_account.full_domain
      user.user_role = User::USER_ROLES_KEYS_BY_TOKEN[:admin]
    else
      user.user_role = User::USER_ROLES_KEYS_BY_TOKEN[:customer]
    end
    user.active = true   
    user.save 
    user.reset_persistence_token! 
    if AppConfig['demo_site'][RAILS_ENV] == current_account.full_domain
      agent = Agent.new
      agent.user_id = user.id
      agent.save
    end
    Authorization.create(:user_id => user.id, :uid => hash['uid'], :provider => hash['provider'],:account_id => current_account.id)
  end
  
  def failure
    flash[:notice] = "Authentication Failed"
    redirect_to root_url
  end
  
  def destroy
    @authorization = current_user.authorizations.find(params[:id])
    @authorization.destroy
    redirect_to root_url
  end
end
