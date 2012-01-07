class Admin::SecurityController <  Admin::AdminController
  
  def index
   @account = current_account  
 end
 
 def update
   @account = current_account  
   @account.sso_enabled = params[:account][:sso_enabled]
   @account.ssl_enabled = params[:account][:ssl_enabled]
   
   if @account.sso_enabled?
    @account.sso_options = params[:account][:sso_options]
   end
   if @account.save
      flash[:notice] = t(:'flash.sso.update.success')
      redirect_to admin_home_index_path
   else
      render :action => 'index'
   end
 end
  
end