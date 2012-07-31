class UserSession < Authlogic::Session::Base
  params_key :k
  single_access_allowed_request_types :any


  after_save :remove_orphan_filters
  before_destroy :remove_orphan_filters

	def remove_orphan_filters
		$redis.keys("#{self.attempted_record.id}:*").each {|key| $redis.del(key)}
	end

end
