class UserSession < Authlogic::Session::Base
	include RedisKeys

  params_key :k
  single_access_allowed_request_types :any

  after_create :remove_portal_preview_keys
  before_destroy :remove_portal_preview_keys

  private
  	def remove_portal_preview_keys
      portal_preview_keys = array_of_keys(PORTAL_PREVIEW_PREFIX % {:account_id => self.attempted_record.account_id, 
  				:user_id => self.attempted_record.id})
      portal_preview_keys.each { |key| remove_key(key) } 
    end
end
