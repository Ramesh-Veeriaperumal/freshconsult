class PortalObserver < ActiveRecord::Observer
	observe Topic, Portal::Template, Post, Helpdesk::TicketField, Portal, 
	ForumCategory, Forum, Solution::Category, Solution::Folder, Solution::Article,
	Portal::Page

	include RedisKeys

	def increment_version(*args)
		return unless Account.current
		return if get_key(PORTAL_CACHE_ENABLED) === "false"
		Rails.logger.debug "::::::::::Sweeping from portal"
		key = PORTAL_CACHE_VERSION % { :account_id => Account.current.id }
		increment key
	end
	alias_method :after_save, :increment_version
	alias_method :after_destroy, :increment_version
end