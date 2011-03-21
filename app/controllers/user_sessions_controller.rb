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
  
   def google
    
   
    domainName = params[:domain] 
    
    url = nil
    
    unless domainName.nil?
    
      url = "https://www.google.com/accounts/o8/site-xrds?hd=" + params[:domain]
      
    end
 
  
  authenticate_with_open_id(url,{ :required => ["http://axschema.org/contact/email", :email]}) do |result, identity_url, registration|
    
    puts "after authentication"
    if result.successful?
      
      puts "successfully logged in . need to create session and redirect to home"
      # Succesfully logged in
      
      email = get_email(registration)
      
      #we may need to write a method to find out the account as follows
      #account = Account.find_or_create_by_domain(params[:domain])
      #we may need to write a methode to find out the user from email
      #user = account.users.find_or_create_by_email(email)
      #session[:user_id] = user.id
      #puts email
      #puts "here is ur posts_path" +email
      redirect_back_or_default('/')
    else
      puts "Login failed"
      # Failed to login
      flash[:notice] = "Could not log you in"
      render :index
    end
  end
    
  end
  

  
  private

    def note_failed_login
      #flash[:error] = "Couldn't log you in as '#{params[:user_session][:email]}'"
      logger.warn "Failed login for '#{params[:user_session][:login]}' from #{request.remote_ip} at #{Time.now.utc}"
  end
  
  def get_email(registration)
    puts "getting email id"
  if !registration['email'].blank?
    registration['email']
  else
    ax_response = OpenID::AX::FetchResponse.from_success_response(request.env[Rack::OpenID::RESPONSE])
    ax_response.data["http://axschema.org/contact/email"].first
  end
  end

end
