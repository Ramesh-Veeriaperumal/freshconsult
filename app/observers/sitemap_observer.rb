class SitemapObserver < ActiveRecord::Observer

  observe ForumCategory, Forum, Topic, Post, Solution::CategoryMeta, Solution::Category, Solution::FolderMeta, 
  Solution::Folder, Solution::ArticleMeta, Solution::Article, PortalSolutionCategory, PortalForumCategory

  include Redis::RedisKeys
  include Redis::PortalRedis

  def after_save(item)
    set_sitemap_key(item)
  end

  def after_destroy(item)
    set_sitemap_key(item)
  end

  def set_sitemap_key(item)
    return unless item.account.features_included?(:sitemap)
    key = SITEMAP_OUTDATED % {:account_id => item.account.id}
    set_portal_redis_key(key, 1)
  end

end