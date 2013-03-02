class ActivationsController < ApplicationController
  #before_filter :require_no_user, :only => [:new, :create] #Guess we don't really need this - Shan

  before_filter :only => [:send_invite, :test] do |c| 
    c.requires_permission :manage_users
  end

  def send_invite
    user = current_account.all_users.find params[:id]
    user.deliver_activation_instructions!(current_portal, true) if user and user.has_email?
    respond_to do |format|
      format.html { 
        flash[:notice] = t('users.activations.send_invite_success') 
        redirect_to(:back)
      }
      format.js { 
        render :json => { :activation_sent => true }
      }
    end
  end

  def new
    @user = current_account.users.find_using_perishable_token(params[:activation_code], 1.weeks) 
    if @user.nil?
      flash[:notice] = t('users.activations.code_expired')
      return redirect_to new_password_reset_path
    end
    raise Exception if @user.active? and !@user.account_admin?
  end

  def create
    @user = current_account.users.find(params[:id])
 
    raise Exception if @user.active? and !@user.account_admin?
 
    if @user.activate!(params)
      flash[:notice] = t('users.activations.success')
      Resque::enqueue(CRM::Totango::SendUserAction, 
                                        current_account.id, 
                                        @user.email, 
                                        totango_activity(:account_activation)) if @user.account_admin?
      @current_user = @user
      redirect_to(root_url) if grant_day_pass
    else
      render :action => :new
    end
  end

  protected

    def cname
      "users"
    end

    def scoper
      current_account.users
    end
end
