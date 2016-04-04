class SubscriptionAdmin::AdminSessionsController < ApplicationController

  include AdminControllerMethods
  include TwoFactorAuthentication

  skip_before_filter :check_admin_user_privilege
 
  def index
    redirect_to(admin_subscription_login_path)
  end
 
  def new
    @admin_session = scoper.new
  end
 
  def create
  	email_id = params[:admin_session][:email]
  	@admin_session = scoper.new(params[:admin_session])
  	user_entered_otp = params[:admin_session][:otp]
  	otp_alive = otp_exists?(email_id)
  	if user_entered_otp && !otp_alive
      flash[:notice] = "Your one time password is expired. Regenerate one." 
      render :action => "new" and return
    end
  	if !otp_alive
  		if @admin_session.valid?
  			flash[:notice] = "We have sent you an email with one time password. Please authenticate using that token"
  			send_otp_via_mail(email_id)
  			@key_exists = true
  		else
  			flash[:notice] = "Username or password is wrong"
  		end
  	else
  		if validate_otp(email_id,user_entered_otp) && @admin_session.save
  			clear_otp(email_id)
  			flash[:notice] = "Welcome, #{current_user.name}, You have logged in!"
  			redirect_to(root_url) and return
  		else
  			@key_exists = otp_alive
  			flash[:notice] = "Your password is wrong or otp is either wrong or expired"
  		end
  	end

  	@key_exists = otp_exists?(email_id)
    render :action => "new"
  end
 
  def destroy	
    current_user_session.destroy unless current_user_session.nil?
    flash[:notice] = "You are now logged out"
    redirect_to(admin_subscription_login_url)
  end

  def last_request_update_allowed?
    action_name == "create"
  end

  private

    def scoper
      AdminSession
    end

    def log_file
      @log_file_path = "#{Rails.root}/log/admin_user.log"      
    end 
    
    def logging_format
      @log_file_format = "ip=#{request.env['CLIENT_IP']}, domain=#{request.env['HTTP_HOST']}, controller=#{request.parameters[:controller]}, action=#{request.parameters[:action]}, url=#{request.url}, Time: #{Time.now.utc}, email: #{request.parameters[:admin_session] and request.parameters[:admin_session][:email]} server_ip=#{request.env['SERVER_ADDR']}"     
    end 
end