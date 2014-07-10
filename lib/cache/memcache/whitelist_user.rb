module Cache::Memcache::WhitelistUser

	include MemcacheKeys

	def whitelist_users
		key = WHITELISTED_USERS
		MemcacheKeys.fetch(key) {WhitelistUser.all.map(&:user_id) }
	end

	def clear_whitelist_users_cache
		key = WHITELISTED_USERS
		MemcacheKeys.delete_from_cache key
	end

end