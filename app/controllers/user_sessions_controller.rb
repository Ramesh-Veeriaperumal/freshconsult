class UserSessionsController < ApplicationController
  
require 'gapps_openid'
require 'rack/openid'
require 'uri'
require 'openid'

 layout "ssportal"
  
  skip_before_filter :require_user, :except => :destroy
  
  def new
    @user_session = current_account.user_sessions.new
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
    redirect_to root_url
  end
  
  def google_auth       
    return_url = url_for('http://localhost:3000/authdone/google?domain='+params[:domain]) 
    domain_name = params[:domain] 
    logger.debug "domain name is :: #{domain_name}"
    url = nil    
    url = ("https://www.google.com/accounts/o8/site-xrds?hd=" + params[:domain]) unless domain_name.blank?
    authenticate_with_open_id(url,{ :required => ["http://axschema.org/contact/email", :email] , :return_to => return_url}) do |result, identity_url, registration|
      
    end  
  end
  
  

  def google_auth_completed
    
  resp = request.env[Rack::OpenID::RESPONSE]
  email = get_email resp
  @current_user = User.find_by_email(email)  
  @current_user.email = email 
  @user_session = @current_user.account.user_sessions.create(@current_user)
  if @user_session.save      
      flash[:notice] = "Login successful!"
      redirect_back_or_default(@current_user.account.full_domain)
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

end
