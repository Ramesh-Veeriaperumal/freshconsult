class SitemapObserver < ActiveRecord::Observer

  observe ForumCategory, Forum, Topic, Post, Solution::CategoryMeta, Solution::Category, Solution::FolderMeta, 
  Solution::Folder, Solution::ArticleMeta, Solution::Article, PortalSolutionCategory, PortalForumCategory, Features::Feature

  include Redis::RedisKeys
  include Redis::PortalRedis

  def after_save(item)
    set_sitemap_key(item)
  end

  def after_destroy(item)
    set_sitemap_key(item)
  end

  def set_sitemap_key(item)
    return unless (item.account.features_included?(:sitemap) && sitemap_trigger?(item))
    key = SITEMAP_OUTDATED % {:account_id => item.account.id}
    set_portal_redis_key(key, 1)
  end
 
  def sitemap_trigger?(item)
    return true unless item.class.name.include?("Feature") #Needed to check only for Feature class
    sitemap_triggers = [:open_solutions, :open_forums, :hide_portal_forums].map { |f| "#{f.to_s.camelize}Feature" }
    sitemap_triggers.include?(item.type)
  end

end