class SubscriptionAdmin::CustomSslController < ApplicationController
	include AdminControllerMethods
  include Redis::RedisKeys
  include Redis::OthersRedis

  skip_filter :read_on_slave, :only => [:enable_custom_ssl]
  skip_filter :select_shard
  skip_before_filter :determine_pod

	def index
		@portals = Sharding.run_on_all_slaves { Portal.find(:all, :conditions => ["elb_dns_name is not null"]) }
		@portals = @portals.paginate( :page => params[:page], :per_page => 25)
	end

	def enable_custom_ssl
		Sharding.select_shard_of(params[:account_id]) do
			account = Account.find(params[:account_id])
			account.make_current
			account.update_attributes( :ssl_enabled => 1 )
			portal = account.portals.find_by_portal_url(params[:portal_url])
			portal.update_attributes( :elb_dns_name => params[:elb_name], :ssl_enabled => 1 )
			remove_others_redis_key(ssl_key)
			UserNotifier.send_later(:deliver_custom_ssl_activation, account, 
																params[:portal_url], 
																params[:elb_name])
		end
		Account.reset_current_account
		redirect_to admin_custom_ssl_index_path
	end

	def ssl_key
		CUSTOM_SSL % { :account_id => params[:account_id] }
	end

	def check_admin_user_privilege
      if !(current_user and  current_user.has_role?(:manage_admin))
        flash[:notice] = "You dont have access to view this page"
        redirect_to(admin_subscription_login_path)
      end
    end 
end