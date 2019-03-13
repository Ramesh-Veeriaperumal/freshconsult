module CustomMemcacheKeys

	PORTAL_SOLUTION_CACHE = "PORTAL_SOLUTION_CACHE:v%{cache_version}:%{account_id}:%{portal_id}:%{language_code}:%{visibility_key}:%{company_ids}"
  UNASSOCIATED_CATEGORIES = "UNASSOCIATED_CATEGORIES:%{account_id}"
	
	class << self

		include MemcacheReadWriteMethods

		def memcache_client
			$custom_memcache
		end
	end
end