class SubscriptionAdmin::CustomSslController < ApplicationController
	include AdminControllerMethods
	include RedisKeys

	def index
		@portals = Portal.find(:all, :conditions => ["elb_dns_name is not null"])
		@portals = @portals.paginate( :page => params[:page], :per_page => 30)
	end

	def enable_custom_ssl
		account = Account.find(params[:account_id])
		account.update_attributes( :ssl_enabled => 1 )
		account.main_portal.update_attributes( :elb_dns_name => params[:elb_name], :ssl_enabled => 1 )
		remove_key(ssl_key)
		UserNotifier.send_later(:deliver_custom_ssl_activation, account.account_admin, 
																account.main_portal.portal_url, 
																params[:elb_name])
		redirect_to admin_custom_ssl_index_path
	end

	def ssl_key
		CUSTOM_SSL % { :account_id => params[:account_id] }
	end
end