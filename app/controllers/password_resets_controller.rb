class PasswordResetsController < ApplicationController
  before_filter :require_no_user
  before_filter :load_user_using_perishable_token, :only => [:edit, :update]
  
  def new
    render
  end
  
  def create
    @user = current_account.users.find_by_email(params[:email])
    if @user
      @user.deliver_password_reset_instructions!
      flash[:notice] = t(:'flash.password_resets.email.success')
      redirect_to root_url
    else
      flash[:notice] = t(:'flash.password_resets.email.user_not_found')
      render :action => :new
    end
  end
  
  def edit
    render
  end

  def update
    @user.password = params[:user][:password]
    @user.password_confirmation = params[:user][:password_confirmation]
    @user.active = true #by Shan need to revisit..
    if @user.save
      flash[:notice] = t(:'flash.password_resets.update.success')
      redirect_to root_url
    else
      render :action => :edit
    end
  end

  private
    def load_user_using_perishable_token
      @user = current_account.users.find_using_perishable_token(params[:id])
      unless @user
        flash[:notice] = t(:'flash.password_resets.update.invalid_token')
        redirect_to root_url
      end
    end
end
