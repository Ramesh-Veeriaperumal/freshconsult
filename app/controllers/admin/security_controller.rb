class Admin::SecurityController <  Admin::AdminController

  include RedisKeys
  
  def index
   @account = current_account  
   @portal = current_account.main_portal
   @custom_ssl_requested = get_key(ssl_key).to_i
 end
 
 def update
   @account = current_account  
   @account.sso_enabled = params[:account][:sso_enabled]
   @account.ssl_enabled = params[:account][:ssl_enabled]
   
   if params[:ssl_type].present?
    current_account.main_portal.update_attributes( :ssl_enabled => params[:ssl_type] )
   end
   
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

 def ssl_key
  CUSTOM_SSL % { :account_id => current_account.id }
 end

 def request_custom_ssl
   set_key(ssl_key, "1", 86400*10)
   current_account.main_portal.update_attributes( :portal_url => params[:domain_name] )
   FreshdeskErrorsMailer.deliver_error_email( nil, 
                                              { "domain_name" => params[:domain_name] }, 
                                              nil, 
                                              { :subject => "Request for new SSL Certificate -
                                                           Account ID ##{current_account.id}" })
   render :json => { :success => true }
 end 
end