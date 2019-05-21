class SupportPortalObserver < ActiveRecord::Observer

  observe Topic, Portal::Template, Post, Helpdesk::TicketField, ContactField, Portal, 
	ForumCategory, Forum, Solution::Category, Solution::Folder, Solution::Article, Solution::ArticleBody,
	Solution::CategoryMeta, Solution::FolderMeta, Solution::ArticleMeta, 
	Portal::Page, ChatSetting, ChatWidget, BusinessCalendar, PortalSolutionCategory, PortalForumCategory,
	Subscription, AccountAdditionalSettings, Account, Bot, Freshchat::Account

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
		return if (args.first.present? && args.first.class.name == "Account" && !args.first.changes.has_key?("ssl_enabled"))
		key = PORTAL_CACHE_VERSION % { :account_id => Account.current.id }
		increment_portal_redis_version key
	end

end