class Support::PreviewController < SupportController
	before_filter { |c| c.requires_permission :manage_users }
	before_filter :preview_url, :only => :index
  include Redis::RedisKeys
  include Redis::PortalRedis

  private
  	def preview_url
    	preview_key = PREVIEW_URL % { :account_id => current_account.id, 
      :user_id => User.current.id, :portal_id => current_portal.id}
      @preview_url = get_portal_redis_key(preview_key) || support_home_url      
  	end

end