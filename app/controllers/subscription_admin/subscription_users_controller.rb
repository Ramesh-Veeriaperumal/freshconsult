class SubscriptionAdmin::SubscriptionUsersController < ApplicationController

  include AdminControllerMethods
  before_filter :set_selected_tab
  before_filter :check_super_admin_role, :only => :update
  skip_before_filter :check_admin_user_privilege, :only => [:show, :reset_password]

  def index
    @admin_user = scoper.all
  end
 
  def new
    @admin_user = scoper.new
  end

  def show
    @admin_user = scoper.find(params[:id])
  end
 
  def update
    @admin_user = scoper.find(params[:id])
    @admin_user.toggle!("active")
    respond_to do |format|
      format.json {render :json => {"active" => @admin_user.active?}}
    end
  end

  def reset_password    
      @check_session = AdminSession.new(:email => current_user.email, :password => params[:admin_user][:password])
      if @check_session.valid? && change_password 
        flash[:notice] = 'Password Changed successfully'
        @check_session.destroy
        current_user_session.destroy
        redirect_to admin_subscription_login_path      
      else     
        if @check_session.valid?
          flash[:notice] = 'New password does not match.'
        else
          flash[:notice] = "Wrong password"
        end
         
        redirect_to :back
      end      
  end

  private
    def scoper
      AdminUser
    end

    def set_selected_tab
       @selected_tab = :admin_users
    end

    def check_admin_user_privilege
      if !(current_user and current_user.has_role?(:manage_admin))
        flash[:notice] = "You dont have access to view this page"
        redirect_to(admin_subscription_login_path)
      end
    end 

    def check_super_admin_role
      unless current_user.has_role?(:manage_admin)
        flash[:notice] = "Not authorized to do this action!!!"
        redirect_to(admin_subscription_login_path)
      end
    end

    def change_password
      return false if params[:admin_user][:new_password] != params[:admin_user][:password_confirmation]
      @admin_user = current_user
      @admin_user.password = params[:admin_user][:new_password]
      @admin_user.password_confirmation = params[:admin_user][:password_confirmation]
      @admin_user.active = true
      @admin_user.save
    end
end