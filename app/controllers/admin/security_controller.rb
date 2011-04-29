class Admin::SecurityController <  Admin::AdminController
  
  def index
   @account = current_account  
 end
 
 def update
   @account = current_account  
   @account.sso_enabled = params[:account][:sso_enabled]
   
   if @account.sso_enabled?
    @account.sso_options = params[:account][:sso_options]
   end
   if @account.save
      flash[:notice] = "Your account details have been updated."
      redirect_to admin_home_index_path
   else
      render :action => 'index'
   end
 end
  
end