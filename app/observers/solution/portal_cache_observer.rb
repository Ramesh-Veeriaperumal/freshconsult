class Solution::PortalCacheObserver < ActiveRecord::Observer

	include Redis::PortalRedis

	observe Solution::Category, Solution::Folder, Solution::Article, 
	  Solution::CategoryMeta, Solution::FolderMeta, Solution::ArticleMeta, PortalSolutionCategory

	def after_commit(item)
		if (item.send(:transaction_include_action?, :create) || 
			item.send(:transaction_include_action?, :update) ||
			item.send(:transaction_include_action?, :destroy)) 
			increment_version_and_enqueue_flush(item)
		end
	end

	def increment_version_and_enqueue_flush(*args)
		return unless Account.current
		Rails.logger.debug ":::::::::: Sweeping portal cache for solutions ::::::::::"
		key = Redis::RedisKeys::SOLUTIONS_PORTAL_CACHE_VERSION % { :account_id => Account.current.id }
		obsolete_version = get_portal_redis_key(key)
		increment_portal_redis_version(key)
		Solution::FlushPortalCache.perform_async(:obsolete_version => obsolete_version)
	end
end