class SupportPortalObserver < ActiveRecord::Observer

  observe Topic, Portal::Template, Post, Helpdesk::TicketField, Portal, 
	ForumCategory, Forum, Solution::Category, Solution::Folder, Solution::Article,
	Portal::Page

	include RedisKeys

	def after_save(item)
	  increment_version(item)
	end

	def after_destroy(item)
	  increment_version(item)
	end

	def increment_version(item)
		return if get_key(PORTAL_CACHE_ENABLED) === "false"
		Rails.logger.debug "::::::::::Sweeping from portal"
		key = PORTAL_CACHE_VERSION % { :account_id => item.account_id }
		increment key
	end

end