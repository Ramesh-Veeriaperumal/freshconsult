class ActivationsController < ApplicationController
  #before_filter :require_no_user, :only => [:new, :create] #Guess we don't really need this - Shan

  include HelpdeskControllerMethods
  
  skip_before_filter :build_item , :only => [:new, :create]
  
  before_filter :only => :send_invite do |c| 
    c.requires_permission :manage_users
  end

  before_filter :load_multiple_items, :only => :bulk_send_invite

  def send_invite
    user = current_account.all_users.find params[:id]
    user.deliver_activation_instructions!(current_portal, true) if user and user.has_email?
    render :json => { :activation_sent => true }
  end

  def bulk_send_invite
    @items.each do |user|
      user.deliver_activation_instructions!(current_portal, true) if user and user.has_email?
    end
    flash[:notice] = render_to_string(:inline => t("users.activations.bulk_send_invite_success", 
      :users => params[:ids].length.to_s() ))
    redirect_to contacts_path
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
