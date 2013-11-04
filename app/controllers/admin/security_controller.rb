class Admin::SecurityController <  Admin::AdminController

  include Redis::RedisKeys
  include Redis::OthersRedis

  before_filter :load_whitelisted_ips, :only => :index
  
  def index
   @account = current_account  
   @portal = current_account.main_portal
   @custom_ssl_requested = get_others_redis_key(ssl_key).to_i
 end
 
 def update
   @account = current_account  
   @account.sso_enabled = params[:account][:sso_enabled]
   @account.ssl_enabled = params[:account][:ssl_enabled]
   @account.whitelisted_ip.enabled = params[:account][:whitelisted_ip_attributes][:enabled] unless 
   						@account.whitelisted_ip.nil?
   						
   if current_account.features?(:whitelisted_ips) && (@account.whitelisted_ip ? 
   						@account.whitelisted_ip.enabled : params[:account][:whitelisted_ip_attributes][:enabled])
   		@account.whitelisted_ip_attributes = params[:account][:whitelisted_ip_attributes]
			@whitelisted_ips = @account.whitelisted_ip
			@whitelisted_ips.load_ip_info(request.env['CLIENT_IP'])
   end

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
      @portal = current_account.main_portal
      @custom_ssl_requested = get_others_redis_key(ssl_key).to_i
      render :action => 'index'
   end
 end

 def ssl_key
  CUSTOM_SSL % { :account_id => current_account.id }
 end

 def request_custom_ssl
   set_others_redis_key(ssl_key, "1", 86400*10)
   current_account.main_portal.update_attributes( :portal_url => params[:domain_name] )
   FreshdeskErrorsMailer.deliver_error_email( nil, 
                                              { "domain_name" => params[:domain_name] }, 
                                              nil, 
                                              { :subject => "Request for new SSL Certificate -
                                                           Account ID ##{current_account.id}" })
   render :json => { :success => true }
 end 

 def load_whitelisted_ips
		if current_account.features?(:whitelisted_ips)
			@whitelisted_ips = current_account.whitelisted_ip_from_cache || current_account.build_whitelisted_ip
		end
 end
end