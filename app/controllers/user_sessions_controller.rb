class UserSessionsController < ApplicationController
  skip_before_filter :require_user, :except => :destroy
  
  def new
    @user_session = UserSession.new
  end
  
  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      flash[:notice] = "Login successful!"
      redirect_back_or_default('/')
    else
      note_failed_login
      render :action => :new
    end
  end
  
  def destroy
    current_user_session.destroy
    flash[:notice] = "Logout successful!"
    redirect_to login_url
  end
  
  private

    def note_failed_login
      flash[:error] = "Couldn't log you in as '#{params[:user_session][:email]}'"
      logger.warn "Failed login for '#{params[:user_session][:login]}' from #{request.remote_ip} at #{Time.now.utc}"
    end

end
