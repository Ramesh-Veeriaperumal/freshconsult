class UserSessionsController < ApplicationController
  
require 'gapps_openid'
require 'rack/openid'
require 'uri'
require 'openid'
  
  skip_before_filter :require_user, :except => :destroy
  before_filter :check_sso_params, :only => :sso_login
  
  def new
    if current_account.sso_enabled? and (request.request_uri != "/login/normal")
       redirect_to  current_account.sso_options[:login_url]
    end
    @user_session = current_account.user_sessions.new
  end
  
 
  def check_sso_params
    if params[:name].blank? or params[:email].blank? or params[:hash].blank?
      flash[:notice] = "Expected params are name, email and hash which are not present "
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end
  
  def sso_login
      if params[:hash] == gen_hash_from_params_hash
          @current_user = current_account.users.find_by_email(params[:email])  
          @current_user = create_user(params[:email],current_account) if @current_user.blank?  
          @user_session = @current_user.account.user_sessions.new(@current_user)
          if @user_session.save
              flash[:notice] = "Login successful!"      
              redirect_back_or_default('/')      
          else
              redirect_to current_account.sso_options[:login_url]
          end
      else
        redirect_to current_account.sso_options[:login_url]
      end
   end
  
  def gen_hash_from_params_hash
     Digest::MD5.hexdigest(params[:name]+params[:email]+current_account.shared_secret)
  end
  
  def show
    redirect_to :action => :new
  end
  
  def create   
    @user_session = current_account.user_sessions.new(params[:user_session])
    if @user_session.save
      #flash[:notice] = "Login successful!"
      redirect_back_or_default('/')
    else
      note_failed_login
      render :action => :new
    end
  end
  
  def destroy
    current_user_session.destroy
    #flash[:notice] = "Logout successful!"
    if current_account.sso_enabled? and !current_account.sso_options[:logout_url].blank?
      redirect_to current_account.sso_options[:logout_url]
    end
    redirect_to root_url
  end
  
  
  
  def google_auth
    base_domain = AppConfig['base_domain'][RAILS_ENV]
    domain_name = params[:domain] 
    logger.debug "base domain is #{base_domain}"
    full_domain  = "#{domain_name.split('.').first}.#{AppConfig['base_domain'][RAILS_ENV]}"
    @current_account = Account.find_by_full_domain(full_domain)
    cust_url = @current_account.full_domain unless @current_account.blank?
    return :back if @current_account.blank?
    ##Need to handle the case where google is integrated with a seperate domain-- 2 times we need to authenticate
    return_url = "http://"+cust_url+"/authdone/google?domain="+params[:domain] 
    logger.debug "the return_url is :: #{return_url}"
    
    re_alm = "http://*."+base_domain
    
    logger.debug "domain name is :: #{domain_name}"
    url = nil    
    url = ("https://www.google.com/accounts/o8/site-xrds?hd=" + params[:domain]) unless domain_name.blank?
    authenticate_with_open_id(url,{ :required => ["http://axschema.org/contact/email", :email] , :return_to => return_url, :trust_root =>re_alm}) do |result, identity_url, registration|
      
    end  
  end
  
  

  def google_auth_completed
    
  resp = request.env[Rack::OpenID::RESPONSE]
  logger.debug "The response is :: #{resp.inspect}"
  email = get_email resp  
  domain_name = params[:domain]    
  full_domain  = "#{domain_name.split('.').first}.#{AppConfig['base_domain'][RAILS_ENV]}"
  @current_account = Account.find_by_full_domain(full_domain)   
  @current_user = @current_account.users.find_by_email(email)  unless  @current_account.blank?
  @current_user = create_user(email,@current_account) if (@current_user.blank? && !@current_account.blank?)
  @current_user = User.find_by_email(email) if @current_account.blank?  
  return :back if @current_user.blank?
  @current_user.email = email   
  @user_session = @current_user.account.user_sessions.new(@current_user)  
  if @user_session.save
      logger.debug " @user session has been saved :: #{@user_session.inspect}"
      flash[:notice] = "Login successful!"      
      redirect_back_or_default('/')      
  else
      note_failed_login
      render :action => :new
  end
end
 
  private

    def note_failed_login
      #flash[:error] = "Couldn't log you in as '#{params[:user_session][:email]}'"
      logger.warn "Failed login for '#{params[:user_session][:login]}' from #{request.remote_ip} at #{Time.now.utc}"
  end
  
def get_email(resp)
   if resp.status == :success
    session[:openid] = resp.display_identifier
    logger.debug "display_identifier is ::: #{resp.display_identifier}"
    ax_response = OpenID::AX::FetchResponse.from_success_response(resp)
    email = ax_response.data["http://axschema.org/contact/email"].first  
    
  else
    "Error: #{resp.status}"
  end
end

 def create_user(email, account)
   logger.debug "create user has beeen called ::"
      @contact = account.users.new
      @contact.email = email
      @contact.user_role = User::USER_ROLES_KEYS_BY_TOKEN[:customer]
      @contact.active = true     
      @contact.save  
      return @contact
  end

end
