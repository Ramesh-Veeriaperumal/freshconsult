class SupportPortalObserver < ActiveRecord::Observer

  observe Topic, Portal::Template, Post, Helpdesk::TicketField, Portal, 
	ForumCategory, Forum, Solution::Category, Solution::Folder, Solution::Article,
	Portal::Page

	include Redis::RedisKeys
	include Redis::PortalRedis

	def after_save(item)
	  increment_version(item)
	end

	def after_destroy(item)
	  increment_version(item)
	end

	def increment_version(*args)
		return unless Account.current
		return if get_portal_redis_key(PORTAL_CACHE_ENABLED) === "false"
		Rails.logger.debug "::::::::::Sweeping from portal"
		key = PORTAL_CACHE_VERSION % { :account_id => Account.current.id }
		increment_portal_redis_version key
	end

end