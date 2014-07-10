class SubscriptionAdmin::ManageUsersController < ApplicationController
	include ModelControllerMethods
  include AdminControllerMethods

  before_filter :set_selected_tab ,  :load_whitelist_user

  def index
     @whitelisted_id_pagination = @user_ids.paginate( :page => params[:page], :per_page => 5) if @user_ids
  end

  def add_whitelisted_user_id
    item = WhitelistUser.new( :user_id => params[:user_id], :account_id => params[:account_id])
    if item.save
      flash[:notice] = "User ID #{params[:user_id]}  Whitelisted"
      redirect_to :action => 'index'
    else
      flash[:notice] = "Adding Whitelisted User ID Failed"
      redirect_to :action => 'index'
    end
  end

  def remove_whitelisted_user_id
    item = WhitelistUser.find_by_user_id(params[:user_id])
    if item.destroy
      flash[:notice] = "User ID #{params[:user_id]} removed"
      redirect_to :action => 'index'
    else
      flash[:notice] = "Failed to remove user_id #{params[:user_id]}"
      redirect_to :action => 'index'
    end
  end
  
  def load_whitelist_user
    @user_ids = WhitelistUser.all.map { |e| [e.user_id,e.account_id ] }
  end

  protected
    def set_selected_tab
       @selected_tab = :users
    end   

    def check_admin_user_privilege
      if !(current_user and  current_user.has_role?(:users))
        flash[:notice] = "You dont have access to view this page"
        redirect_to(admin_subscription_login_path)
      end
    end 
end