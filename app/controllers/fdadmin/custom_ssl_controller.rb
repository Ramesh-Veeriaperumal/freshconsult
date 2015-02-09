class Fdadmin::CustomSslController < Fdadmin::DevopsMainController

	include Redis::RedisKeys
  include Redis::OthersRedis

  skip_filter :read_on_slave, :only => [:enable_custom_ssl]
  skip_filter :select_shard

	def index
		portal_record = []
		portals = Sharding.run_on_all_slaves { Portal.find(:all, :conditions => ["elb_dns_name is not null"]) }
		portals.each do |port_record|
			portal_record << {
												:portal_name => port_record.name,
												:account_id => port_record.account_id,
												:portal_url => port_record.portal_url,
												:elb_dns_name => port_record.elb_dns_name,
												:account_name => port_record.account.name
											 }
		end
		respond_to do |format| 
			format.json do 
				render :json => {:data => portal_record}
			end
		end
	end

	def enable_custom_ssl
		result = {}
		Sharding.select_shard_of(params[:account_id]) do
			account = Account.find(params[:account_id])
			account.make_current
			account.update_attributes( :ssl_enabled => 1 )
			portal = account.portals.find_by_portal_url(params[:portal_url])
			if portal
				portal.update_attributes( :elb_dns_name => params[:elb_name], :ssl_enabled => 1 ) 
				result[:status] = "success"
			else
				result[:status] = "error"
			end
			remove_others_redis_key(ssl_key)
			UserNotifier.send_later(:deliver_custom_ssl_activation, account, 
																params[:portal_url], 
																params[:elb_name])
			result[:account_id] = account.id
			result[:account_name] = account.name
		end
		Account.reset_current_account
		respond_to do |format| 
			format.json do 
				render :json => result
			end
		end
	end

	def ssl_key
		CUSTOM_SSL % { :account_id => params[:account_id] }
	end

end
