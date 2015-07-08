class Fdadmin::ManageUsersController < Fdadmin::DevopsMainController

  def get_whitelisted_users
    user = WhitelistUser.find_by_user_id(params[:user_id])
    render :json => {:user_found => user ? params[:user_id] : false }
  end

  def add_whitelisted_user_id
    item = WhitelistUser.new( :user_id => params[:user_id], :account_id => params[:account_id])
    render :json => {:status => item.save ? "success" : "error"}
  end

  def remove_whitelisted_user_id
    item = WhitelistUser.find_by_user_id(params[:user_id])
    render :json => {:status => item.destroy ? "success" : "error"}
  end
end
