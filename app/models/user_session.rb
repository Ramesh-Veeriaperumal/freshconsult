class UserSession < Authlogic::Session::Base
	include RedisKeys

  params_key :k
  single_access_allowed_request_types :any

  # after_create :remove_portal_preview_keys
  # before_destroy :remove_portal_preview_keys

  after_save :set_node_session
  before_destroy :delete_node_session
  after_validation :set_missing_node_session

  SECRET_KEY = "3f1fd135e84c2a13c212c11ff2f4b205725faf706345716f4b6996f9f8f2e6472f5784076c4fe102f4c6eae50da0fa59a9cc8cf79fb07ecc1eef62e9d370227f"

  def set_node_session
    generated_hash = Digest::SHA512.hexdigest("#{SECRET_KEY}::#{self.attempted_record.id}")
    controller.cookies['helpdesk_node_session'] = generated_hash
  end

  def delete_node_session
    controller.cookies.delete 'helpdesk_node_session'
  end
  
  def set_missing_node_session
    if controller.cookies['helpdesk_node_session'].blank?
      generated_hash = Digest::SHA512.hexdigest("#{SECRET_KEY}::#{self.attempted_record.id}")
      controller.cookies['helpdesk_node_session'] = generated_hash
    end
  end

  # private
  #   def remove_portal_preview_keys
  #     portal_preview_keys = array_of_keys(PORTAL_PREVIEW_PREFIX % {:account_id => self.attempted_record.account_id, 
  #         :user_id => self.attempted_record.id})
  #     portal_preview_keys.each { |key| remove_key(key) } 
  #   end
end
