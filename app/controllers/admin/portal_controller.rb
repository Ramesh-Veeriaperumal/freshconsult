class Admin::PortalController < Admin::AdminController
  def index
    @account = current_account
  end
  
  def update
    current_account.update_attributes!(params[:account])
    flash[:notice] = 'Customer portal settings have been updated.'
    redirect_to '/admin/home' #Too much heat.. will think about the better way later. by shan
  end

end
